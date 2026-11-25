import {
  PooledDecartKey,
  resolveDecartApiKeyPool,
  updateDecartKeyTelemetry,
} from './secret_resolver.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Content-Type': 'application/json',
  'Cache-Control': 'no-store',
};

const respond = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: cors });

interface QuotaResult {
  allowed: boolean;
  reason?: string | null;
  enabled: boolean;
  session_duration_seconds: number;
  daily_limit: number;
  used_today: number;
  remaining_today: number;
}

interface KeyCreditProbe {
  credits: number | null;
  status: 'active' | 'low' | 'depleted' | 'invalid' | 'unknown';
  errorCode: string | null;
}

async function isActiveAdmin(
  url: string,
  serviceKey: string,
  userId: string,
): Promise<boolean> {
  const res = await fetch(
    `${url}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=role,is_active&limit=1`,
    {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
      signal: AbortSignal.timeout(8000),
    },
  );
  if (!res.ok) return false;
  const rows = await res.json();
  if (!Array.isArray(rows) || rows.length === 0) return false;
  return rows[0]?.role === 'admin' && rows[0]?.is_active === true;
}

function extractNumericCredits(payload: unknown): number | null {
  if (typeof payload === 'number' && Number.isFinite(payload)) {
    return payload;
  }
  if (typeof payload === 'string') {
    const parsed = Number(payload);
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (!payload || typeof payload !== 'object') return null;

  const obj = payload as Record<string, unknown>;
  const candidateKeys = [
    'credits',
    'balance',
    'remaining_credits',
    'remainingCredits',
    'remaining',
    'available_credits',
    'availableCredits',
    'tokens',
  ];
  for (const key of candidateKeys) {
    const val = obj[key];
    if (typeof val === 'number' && Number.isFinite(val)) return val;
    if (typeof val === 'string' && val.trim() !== '') {
      const n = Number(val);
      if (Number.isFinite(n)) return n;
    }
  }
  if (obj.data && typeof obj.data === 'object') {
    return extractNumericCredits(obj.data);
  }
  return null;
}

async function probeKeyCredits(apiKey: string, timeoutMs = 8000): Promise<KeyCreditProbe> {
  try {
    const creditRes = await fetch('https://api.decart.ai/v1/credits', {
      method: 'GET',
      headers: {
        'x-api-key': apiKey,
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(timeoutMs),
    });

    if (creditRes.status === 401 || creditRes.status === 403) {
      return { credits: null, status: 'invalid', errorCode: 'invalid_key' };
    }
    if (creditRes.status === 402) {
      return { credits: 0, status: 'depleted', errorCode: null };
    }
    if (!creditRes.ok) {
      return { credits: null, status: 'unknown', errorCode: `upstream_${creditRes.status}` };
    }

    const data: unknown = await creditRes.json();
    const credits = extractNumericCredits(data);
    if (credits === null) {
      return { credits: null, status: 'unknown', errorCode: 'invalid_response' };
    }
    const rounded = Number(Math.max(credits, 0).toFixed(2));
    const status = rounded <= 0 ? 'depleted' : (rounded < 100 ? 'low' : 'active');
    return { credits: rounded, status, errorCode: null };
  } catch {
    return { credits: null, status: 'unknown', errorCode: 'timeout' };
  }
}

async function handleAdminCreditsRequest(
  url: string,
  serviceKey: string,
  userId: string,
): Promise<Response> {
  const adminOk = await isActiveAdmin(url, serviceKey, userId);
  if (!adminOk) return respond({ error: 'Admin access required' }, 403);

  const pool = await resolveDecartApiKeyPool(
    url,
    serviceKey,
    Deno.env.get('DECART_API_KEY'),
  );
  const checkedAt = new Date().toISOString();

  if (pool.length === 0) {
    return respond({
      configured: false,
      credits: null,
      usd: null,
      totalKeys: 0,
      activeKeys: 0,
      depletedKeys: 0,
      invalidKeys: 0,
      checkedAt,
      keys: [],
    });
  }

  // Probe all active keys in parallel for fast, live aggregated balance.
  const results = await Promise.all(
    pool.map(async (item: PooledDecartKey) => {
      if (!item.isActive) {
        return {
          id: item.id,
          label: item.label,
          keyHint: item.keyHint,
          priority: item.priority,
          isActive: false,
          credits: item.lastCredits,
          usd: item.lastCredits != null ? Number((item.lastCredits / 100).toFixed(2)) : null,
          status: item.lastStatus,
          errorCode: null as string | null,
          lastUsedAt: item.lastUsedAt,
        };
      }

      const probe = await probeKeyCredits(item.apiKey, 9000);
      await updateDecartKeyTelemetry(url, serviceKey, {
        id: item.id,
        credits: probe.credits,
        status: probe.status,
      });

      return {
        id: item.id,
        label: item.label,
        keyHint: item.keyHint,
        priority: item.priority,
        isActive: true,
        credits: probe.credits,
        usd: probe.credits != null ? Number((probe.credits / 100).toFixed(2)) : null,
        status: probe.status,
        errorCode: probe.errorCode,
        lastUsedAt: item.lastUsedAt,
      };
    }),
  );

  let totalCredits = 0;
  let anyNumeric = false;
  let activeHealthyCount = 0;
  let depletedCount = 0;
  let invalidCount = 0;

  for (const r of results) {
    if (!r.isActive) continue;
    if (r.credits !== null) {
      totalCredits += r.credits;
      anyNumeric = true;
    }
    if (r.status === 'active' || r.status === 'low') activeHealthyCount++;
    else if (r.status === 'depleted') depletedCount++;
    else if (r.status === 'invalid') invalidCount++;
  }

  const finalCredits = anyNumeric ? Number(totalCredits.toFixed(2)) : null;
  const finalUsd = finalCredits !== null ? Number((finalCredits / 100).toFixed(2)) : null;
  const allInvalid =
    !anyNumeric &&
    results.some((r) => r.isActive) &&
    results.filter((r) => r.isActive).every((r) => r.status === 'invalid');

  return respond({
    configured: results.some((r) => r.isActive),
    credits: finalCredits,
    usd: finalUsd,
    totalKeys: results.length,
    activeKeys: activeHealthyCount,
    depletedKeys: depletedCount,
    invalidKeys: invalidCount,
    errorCode: allInvalid ? 'invalid_key' : null,
    checkedAt,
    keys: results,
  });
}

async function consumeTryonAttempt(
  url: string,
  serviceKey: string,
  userId: string,
): Promise<QuotaResult | null> {
  const response = await fetch(`${url}/rest/v1/rpc/service_consume_tryon_attempt`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ p_user_id: userId }),
    signal: AbortSignal.timeout(8000),
  });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error('Quota service unavailable');
  return await response.json() as QuotaResult;
}

async function refundTryonAttempt(
  url: string,
  serviceKey: string,
  userId: string,
): Promise<void> {
  try {
    await fetch(`${url}/rest/v1/rpc/service_refund_tryon_attempt`, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ p_user_id: userId }),
      signal: AbortSignal.timeout(5000),
    });
  } catch {
    // Best-effort refund; never mask original error.
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST' && req.method !== 'GET') {
    return respond({ error: 'Method not allowed' }, 405);
  }
  try {
    const auth = req.headers.get('Authorization');
    if (!auth?.startsWith('Bearer ')) return respond({ error: 'Unauthorized' }, 401);
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anonKey || !serviceKey) return respond({ error: 'Service not configured' }, 503);
    const userRes = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: auth, apikey: anonKey },
      signal: AbortSignal.timeout(8000),
    });
    if (!userRes.ok) return respond({ error: 'Unauthorized' }, 401);
    const user = await userRes.json();
    if (!user.id || user.is_anonymous) return respond({ error: 'Unauthorized' }, 401);

    // Admin aggregated live credits balance across all keys via GET.
    if (req.method === 'GET') {
      return await handleAdminCreditsRequest(url, serviceKey, user.id);
    }

    // Enforce manual admin provider switch (if Vidu is selected, block Decart minting).
    try {
      const providerRes = await fetch(`${url}/rest/v1/rpc/service_get_tryon_provider`, {
        method: 'POST',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          'Content-Type': 'application/json',
        },
        body: '{}',
        signal: AbortSignal.timeout(5000),
      });
      if (providerRes.ok) {
        const activeProvider = await providerRes.json();
        if (typeof activeProvider === 'string' && activeProvider.toLowerCase() !== 'decart') {
          return respond({
            error: 'Decart try-on is not the active provider',
            code: 'provider_not_active',
            activeProvider: activeProvider.toLowerCase(),
          }, 409);
        }
      }
    } catch {
      // Graceful fallback if migration 041 is not yet applied.
    }

    const pool = (
      await resolveDecartApiKeyPool(url, serviceKey, Deno.env.get('DECART_API_KEY'))
    ).filter((k) => k.isActive);

    if (pool.length === 0) return respond({ error: 'Service not configured' }, 503);

    const quota = await consumeTryonAttempt(url, serviceKey, user.id);
    if (quota && !quota.allowed) {
      if (quota.reason === 'disabled') {
        return respond({
          error: 'Try-on service disabled by administrator',
          code: 'tryon_disabled',
          sessionDurationSeconds: quota.session_duration_seconds,
          dailyLimit: quota.daily_limit,
          usedToday: quota.used_today,
          remainingToday: quota.remaining_today,
        }, 503);
      }
      return respond({
        error: 'Daily try-on attempt limit reached',
        code: 'daily_limit_reached',
        sessionDurationSeconds: quota.session_duration_seconds,
        dailyLimit: quota.daily_limit,
        usedToday: quota.used_today,
        remainingToday: 0,
      }, 429);
    }

    const sessionDurationSeconds = Math.min(
      Math.max(Number(quota?.session_duration_seconds ?? 30), 10),
      300,
    );
    const model = 'lucy-vton-latest';

    // Smart automatic failover across all active keys in priority order:
    // 1) Pre-flight balance check skips depleted/invalid keys immediately.
    // 2) If token minting fails with 401/402/403/429, marks key and tries next.
    let sawDepleted = false;
    let mintedToken: { apiKey: string; expiresAt?: string } | null = null;
    let selectedKey: PooledDecartKey | null = null;

    for (const candidate of pool) {
      const probe = await probeKeyCredits(candidate.apiKey, 5000);
      if (probe.status === 'invalid') {
        await updateDecartKeyTelemetry(url, serviceKey, {
          id: candidate.id,
          status: 'invalid',
        });
        continue;
      }
      if (probe.status === 'depleted') {
        sawDepleted = true;
        await updateDecartKeyTelemetry(url, serviceKey, {
          id: candidate.id,
          credits: 0,
          status: 'depleted',
        });
        continue;
      }
      if (probe.credits !== null) {
        await updateDecartKeyTelemetry(url, serviceKey, {
          id: candidate.id,
          credits: probe.credits,
          status: probe.status,
        });
      }

      const response = await fetch('https://api.decart.ai/v1/client/tokens', {
        method: 'POST',
        headers: { 'x-api-key': candidate.apiKey, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          expiresIn: Math.max(sessionDurationSeconds + 60, 120),
          allowedModels: [model, 'lucy-vton-3.6', 'lucy-vton-3.5'],
          constraints: { realtime: { maxSessionDuration: sessionDurationSeconds } },
        }),
        signal: AbortSignal.timeout(10000),
      });

      if (response.status === 401 || response.status === 403) {
        await updateDecartKeyTelemetry(url, serviceKey, {
          id: candidate.id,
          status: 'invalid',
        });
        continue;
      }
      if (response.status === 402 || response.status === 429) {
        sawDepleted = true;
        await updateDecartKeyTelemetry(url, serviceKey, {
          id: candidate.id,
          credits: response.status === 402 ? 0 : undefined,
          status: 'depleted',
        });
        continue;
      }
      if (!response.ok) {
        continue;
      }

      const token = await response.json();
      if (typeof token.apiKey === 'string' && token.apiKey) {
        mintedToken = token;
        selectedKey = candidate;
        break;
      }
    }

    if (!mintedToken || !selectedKey) {
      if (quota?.allowed) await refundTryonAttempt(url, serviceKey, user.id);
      if (sawDepleted) {
        return respond({
          error: 'All configured Decart API keys are out of credits',
          code: 'all_keys_depleted',
        }, 503);
      }
      return respond({ error: 'Unable to create session' }, 502);
    }

    await updateDecartKeyTelemetry(url, serviceKey, {
      id: selectedKey.id,
      markUsed: true,
    });

    const iceServers = [{ urls: 'stun:stun.l.google.com:19302' }];
    const turnConfig = Deno.env.get('DECART_ICE_SERVERS_JSON');
    return respond({
      apiKey: mintedToken.apiKey,
      expiresAt: mintedToken.expiresAt,
      model,
      iceServers: turnConfig ? JSON.parse(turnConfig) : iceServers,
      relayOnly: Deno.env.get('DECART_RELAY_ONLY') === 'true',
      sessionDurationSeconds,
      dailyLimit: quota?.daily_limit ?? 3,
      usedToday: quota?.used_today ?? 1,
      remainingToday: quota?.remaining_today ?? 2,
    });
  } catch {
    // Never echo upstream bodies, URLs, or credentials to clients/logs.
    return respond({ error: 'Session service unavailable' }, 503);
  }
});
