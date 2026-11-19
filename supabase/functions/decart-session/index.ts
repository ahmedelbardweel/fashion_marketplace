import { resolveDecartApiKey } from './secret_resolver.ts';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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
  // Allow graceful fallback if migration 019 has not been applied yet.
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
  if (req.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);
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

    const apiKey = await resolveDecartApiKey(
      url, serviceKey, Deno.env.get('DECART_API_KEY'),
    );
    if (!apiKey) return respond({ error: 'Service not configured' }, 503);

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
    const response = await fetch('https://api.decart.ai/v1/client/tokens', {
      method: 'POST',
      headers: { 'x-api-key': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        expiresIn: Math.max(sessionDurationSeconds + 60, 120),
        allowedModels: [model, 'lucy-vton-3.6', 'lucy-vton-3.5'],
        constraints: { realtime: { maxSessionDuration: sessionDurationSeconds } },
      }),
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) {
      if (quota?.allowed) await refundTryonAttempt(url, serviceKey, user.id);
      return respond({ error: 'Unable to create session' }, 502);
    }
    const token = await response.json();
    if (typeof token.apiKey !== 'string' || !token.apiKey) {
      if (quota?.allowed) await refundTryonAttempt(url, serviceKey, user.id);
      return respond({ error: 'Invalid session response' }, 502);
    }
    const iceServers = [{ urls: 'stun:stun.l.google.com:19302' }];
    // Supply short-lived TURN credentials from your TURN credential service.
    // This environment hook also supports development TURN deployments.
    const turnConfig = Deno.env.get('DECART_ICE_SERVERS_JSON');
    return respond({
      apiKey: token.apiKey,
      expiresAt: token.expiresAt,
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
