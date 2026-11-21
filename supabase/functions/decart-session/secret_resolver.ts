const DECART_KEY_RE = /^dct_[A-Za-z0-9][A-Za-z0-9-]{0,63}_[A-Za-z0-9_-]{20,512}$/;

export interface PooledDecartKey {
  id: string | null;
  label: string;
  keyHint: string;
  priority: number;
  isActive: boolean;
  lastCredits: number | null;
  lastStatus: string;
  lastCheckedAt: string | null;
  lastUsedAt: string | null;
  apiKey: string;
}

export async function resolveDecartApiKey(
  url: string,
  serviceKey: string,
  legacyKey: string | undefined,
  fetcher: typeof fetch = fetch,
): Promise<string | undefined> {
  const response = await fetcher(`${url}/rest/v1/rpc/service_decart_api_key`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
    signal: AbortSignal.timeout(10000),
  });
  // Never silently revert to an old key when the database is unavailable.
  if (!response.ok) throw new Error('Secret storage unavailable');
  const savedKey: unknown = await response.json();
  if (savedKey === null) return legacyKey;
  if (
    typeof savedKey !== 'string' ||
    savedKey.trim() !== savedKey ||
    !DECART_KEY_RE.test(savedKey)
  ) {
    throw new Error('Invalid secret storage response');
  }
  return savedKey;
}

export async function resolveDecartApiKeyPool(
  url: string,
  serviceKey: string,
  legacyKey: string | undefined,
  fetcher: typeof fetch = fetch,
): Promise<PooledDecartKey[]> {
  const response = await fetcher(`${url}/rest/v1/rpc/service_decart_api_keys`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
    signal: AbortSignal.timeout(10000),
  });

  // Graceful fallback if migration 027 has not been applied yet.
  if (response.status === 404) {
    const single = await resolveDecartApiKey(url, serviceKey, legacyKey, fetcher);
    if (!single) return [];
    return [
      {
        id: null,
        label: 'المفتاح الأساسي',
        keyHint: `dct_…${single.slice(-4)}`,
        priority: 1,
        isActive: true,
        lastCredits: null,
        lastStatus: 'unknown',
        lastCheckedAt: null,
        lastUsedAt: null,
        apiKey: single,
      },
    ];
  }

  if (!response.ok) throw new Error('Secret pool storage unavailable');
  const raw: unknown = await response.json();
  const rows = Array.isArray(raw) ? raw : [];

  const pool: PooledDecartKey[] = [];
  for (const item of rows) {
    if (!item || typeof item !== 'object') continue;
    const obj = item as Record<string, unknown>;
    const key = typeof obj.api_key === 'string' ? obj.api_key.trim() : '';
    if (!DECART_KEY_RE.test(key)) continue;
    pool.push({
      id: typeof obj.id === 'string' ? obj.id : null,
      label: typeof obj.label === 'string' && obj.label.trim() ? obj.label : 'Decart Key',
      keyHint: typeof obj.key_hint === 'string' ? obj.key_hint : `dct_…${key.slice(-4)}`,
      priority: typeof obj.priority === 'number' ? obj.priority : 100,
      isActive: obj.is_active !== false,
      lastCredits: typeof obj.last_credits === 'number' ? obj.last_credits : null,
      lastStatus: typeof obj.last_status === 'string' ? obj.last_status : 'unknown',
      lastCheckedAt: typeof obj.last_checked_at === 'string' ? obj.last_checked_at : null,
      lastUsedAt: typeof obj.last_used_at === 'string' ? obj.last_used_at : null,
      apiKey: key,
    });
  }

  if (pool.length === 0 && legacyKey && DECART_KEY_RE.test(legacyKey.trim())) {
    const clean = legacyKey.trim();
    pool.push({
      id: null,
      label: 'المفتاح الأساسي',
      keyHint: `dct_…${clean.slice(-4)}`,
      priority: 1,
      isActive: true,
      lastCredits: null,
      lastStatus: 'unknown',
      lastCheckedAt: null,
      lastUsedAt: null,
      apiKey: clean,
    });
  }

  return pool;
}

export async function updateDecartKeyTelemetry(
  url: string,
  serviceKey: string,
  params: {
    id: string | null;
    credits?: number | null;
    status?: 'active' | 'low' | 'depleted' | 'invalid' | 'unknown';
    markUsed?: boolean;
  },
  fetcher: typeof fetch = fetch,
): Promise<void> {
  if (!params.id) return;
  try {
    await fetcher(`${url}/rest/v1/rpc/service_update_decart_key_telemetry`, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        p_id: params.id,
        p_credits: params.credits ?? null,
        p_status: params.status ?? null,
        p_mark_used: params.markUsed === true,
      }),
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    // Best-effort telemetry update; never fail customer/admin requests.
  }
}
