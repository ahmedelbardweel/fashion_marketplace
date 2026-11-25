const VIDU_KEY_RE = /^vda_[A-Za-z0-9][A-Za-z0-9_-]{2,63}_[A-Za-z0-9_-]{16,512}$/;

export interface PooledViduKey {
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

export function maskViduKey(rawKey: string): string {
  const clean = rawKey.trim();
  if (clean.length < 14) return `vda_…${clean.slice(-4) || '****'}`;
  return `${clean.slice(0, 10)}…${clean.slice(-4)}`;
}

export async function resolveViduApiKeyPool(
  url: string,
  serviceKey: string,
  legacyKey: string | undefined,
  fetcher: typeof fetch = fetch,
): Promise<PooledViduKey[]> {
  const response = await fetcher(`${url}/rest/v1/rpc/service_vidu_api_keys`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: '{}',
    signal: AbortSignal.timeout(10000),
  });

  if (response.status === 404) {
    if (legacyKey && VIDU_KEY_RE.test(legacyKey.trim())) {
      const clean = legacyKey.trim();
      return [
        {
          id: null,
          label: 'مفتاح Vidu الأساسي',
          keyHint: maskViduKey(clean),
          priority: 1,
          isActive: true,
          lastCredits: null,
          lastStatus: 'unknown',
          lastCheckedAt: null,
          lastUsedAt: null,
          apiKey: clean,
        },
      ];
    }
    return [];
  }

  if (!response.ok) throw new Error('Vidu secret pool storage unavailable');
  const raw: unknown = await response.json();
  const rows = Array.isArray(raw) ? raw : [];

  const pool: PooledViduKey[] = [];
  for (const item of rows) {
    if (!item || typeof item !== 'object') continue;
    const obj = item as Record<string, unknown>;
    const key = typeof obj.api_key === 'string' ? obj.api_key.trim() : '';
    if (!VIDU_KEY_RE.test(key)) continue;
    pool.push({
      id: typeof obj.id === 'string' ? obj.id : null,
      label: typeof obj.label === 'string' && obj.label.trim() ? obj.label : 'Vidu Key',
      keyHint: typeof obj.key_hint === 'string' ? obj.key_hint : maskViduKey(key),
      priority: typeof obj.priority === 'number' ? obj.priority : 100,
      isActive: obj.is_active !== false,
      lastCredits: typeof obj.last_credits === 'number' ? obj.last_credits : null,
      lastStatus: typeof obj.last_status === 'string' ? obj.last_status : 'unknown',
      lastCheckedAt: typeof obj.last_checked_at === 'string' ? obj.last_checked_at : null,
      lastUsedAt: typeof obj.last_used_at === 'string' ? obj.last_used_at : null,
      apiKey: key,
    });
  }

  if (pool.length === 0 && legacyKey && VIDU_KEY_RE.test(legacyKey.trim())) {
    const clean = legacyKey.trim();
    pool.push({
      id: null,
      label: 'مفتاح Vidu الأساسي',
      keyHint: maskViduKey(clean),
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

export async function updateViduKeyTelemetry(
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
    await fetcher(`${url}/rest/v1/rpc/service_update_vidu_key_telemetry`, {
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
