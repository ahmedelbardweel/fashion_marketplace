import {
  PooledViduKey,
  resolveViduApiKeyPool,
  updateViduKeyTelemetry,
} from './secret_resolver.ts';

const VIDU_HTTP_ORIGIN = 'https://api.vidu.com';
const VIDU_ENT_BASE = `${VIDU_HTTP_ORIGIN}/ent/v2`;

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

interface StoredTask {
  task_id: string;
  user_id: string;
  key_id: string | null;
  state: string;
  refunded: boolean;
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

async function getActiveTryonProvider(
  url: string,
  serviceKey: string,
): Promise<string> {
  try {
    const res = await fetch(`${url}/rest/v1/rpc/service_get_tryon_provider`, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: '{}',
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok) return 'decart';
    const val: unknown = await res.json();
    return typeof val === 'string' && val.trim() ? val.trim().toLowerCase() : 'decart';
  } catch {
    return 'decart';
  }
}

function parseNumericValue(val: unknown): number | null {
  if (typeof val === 'number' && Number.isFinite(val)) return val;
  if (typeof val === 'string' && val.trim() !== '') {
    const parsed = Number(val.trim());
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function extractViduCredits(payload: unknown): number | null {
  if (!payload || typeof payload !== 'object') {
    return parseNumericValue(payload);
  }
  const obj = payload as Record<string, unknown>;

  const sumBucketArray = (arr: unknown): number | null => {
    if (!Array.isArray(arr) || arr.length === 0) return null;
    let total = 0;
    let found = false;
    for (const item of arr) {
      if (!item || typeof item !== 'object') continue;
      const entry = item as Record<string, unknown>;
      const val =
        parseNumericValue(entry.credit_remain) ??
        parseNumericValue(entry.credit_remain_int64) ??
        parseNumericValue(entry.remain_credits) ??
        parseNumericValue(entry.credits);
      if (val !== null) {
        total += val;
        found = true;
      }
    }
    return found ? total : null;
  };

  const fromRemains = sumBucketArray(obj.remains);
  if (fromRemains !== null) return fromRemains;

  const fromGeneral = sumBucketArray(obj.general_remains);
  const fromExclusive = sumBucketArray(obj.exclusive_remains);
  if (fromGeneral !== null || fromExclusive !== null) {
    return (fromGeneral ?? 0) + (fromExclusive ?? 0);
  }

  const fromPackages = sumBucketArray(obj.packages);
  if (fromPackages !== null) return fromPackages;

  if (Array.isArray(obj.remains) && obj.remains.length === 0) {
    return 0;
  }

  for (const k of ['credit_remain', 'remain_credits', 'credits', 'balance']) {
    const parsed = parseNumericValue(obj[k]);
    if (parsed !== null) return parsed;
  }

  if (obj.data && typeof obj.data === 'object') {
    return extractViduCredits(obj.data);
  }
  return null;
}

async function probeViduKeyCredits(
  apiKey: string,
  timeoutMs = 8000,
): Promise<KeyCreditProbe> {
  try {
    const res = await fetch(`${VIDU_ENT_BASE}/credits?show_detail=true`, {
      method: 'GET',
      headers: {
        Authorization: `Token ${apiKey}`,
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(timeoutMs),
    });

    if (res.status === 401 || res.status === 403) {
      return { credits: null, status: 'invalid', errorCode: 'invalid_key' };
    }
    if (res.status === 402) {
      return { credits: 0, status: 'depleted', errorCode: null };
    }
    if (!res.ok) {
      return { credits: null, status: 'unknown', errorCode: `upstream_${res.status}` };
    }

    const data: unknown = await res.json();
    const credits = extractViduCredits(data);
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

  const pool = await resolveViduApiKeyPool(
    url,
    serviceKey,
    Deno.env.get('VIDU_API_KEY'),
  );
  const checkedAt = new Date().toISOString();

  if (pool.length === 0) {
    return respond({
      provider: 'vidu',
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

  const results = await Promise.all(
    pool.map(async (item: PooledViduKey) => {
      if (!item.isActive) {
        return {
          id: item.id,
          label: item.label,
          keyHint: item.keyHint,
          priority: item.priority,
          isActive: false,
          credits: item.lastCredits,
          usd: null,
          status: item.lastStatus,
          errorCode: null as string | null,
          lastUsedAt: item.lastUsedAt,
        };
      }

      const probe = await probeViduKeyCredits(item.apiKey, 9000);
      await updateViduKeyTelemetry(url, serviceKey, {
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
        usd: null,
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
  const allInvalid =
    !anyNumeric &&
    results.some((r) => r.isActive) &&
    results.filter((r) => r.isActive).every((r) => r.status === 'invalid');

  return respond({
    provider: 'vidu',
    configured: results.some((r) => r.isActive),
    credits: finalCredits,
    usd: null,
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
  return (await response.json()) as QuotaResult;
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
    // Best-effort refund.
  }
}

async function recordViduTask(
  url: string,
  serviceKey: string,
  params: {
    taskId: string;
    userId: string;
    keyId: string | null;
    state: string;
    sessionDurationSeconds?: number;
  },
): Promise<void> {
  try {
    const res = await fetch(`${url}/rest/v1/rpc/service_record_vidu_task`, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        p_task_id: params.taskId,
        p_user_id: params.userId,
        p_key_id: params.keyId,
        p_state: params.state,
        p_client_secret: null,
        p_session_duration_seconds: params.sessionDurationSeconds ?? 30,
      }),
      signal: AbortSignal.timeout(5000),
    });
    if (res.status === 404) {
      await fetch(`${url}/rest/v1/rpc/service_record_vidu_task`, {
        method: 'POST',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          p_task_id: params.taskId,
          p_user_id: params.userId,
          p_key_id: params.keyId,
          p_state: params.state,
        }),
        signal: AbortSignal.timeout(5000),
      });
    }
  } catch {
    // Best-effort ledger write.
  }
}

async function getStoredViduTask(
  url: string,
  serviceKey: string,
  taskId: string,
  userId: string,
): Promise<StoredTask | null> {
  try {
    const res = await fetch(`${url}/rest/v1/rpc/service_get_vidu_task`, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ p_task_id: taskId, p_user_id: userId }),
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok) return null;
    const data: unknown = await res.json();
    if (!data || typeof data !== 'object') return null;
    return data as StoredTask;
  } catch {
    return null;
  }
}

async function markViduTaskState(
  url: string,
  serviceKey: string,
  taskId: string,
  userId: string,
  state: string,
  refundIfFailed: boolean,
): Promise<boolean> {
  try {
    const res = await fetch(`${url}/rest/v1/rpc/service_mark_vidu_task_state`, {
      method: 'POST',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        p_task_id: taskId,
        p_user_id: userId,
        p_state: state,
        p_refund_if_failed: refundIfFailed,
      }),
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok) return false;
    const val: unknown = await res.json();
    return val === true;
  } catch {
    return false;
  }
}

function isValidImageInput(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  const trimmed = value.trim();
  if (trimmed.length < 12 || trimmed.length > 6_000_000) return false;
  return (
    trimmed.startsWith('https://') ||
    trimmed.startsWith('http://') ||
    /^data:image\/(jpeg|jpg|png|webp);base64,[A-Za-z0-9+/=\s]+$/i.test(trimmed) ||
    trimmed.startsWith('ssupload:?id=')
  );
}

function looksLikeCreditError(status: number, bodyText: string): boolean {
  if (status === 402 || status === 429) return true;
  const lower = bodyText.toLowerCase();
  return (
    lower.includes('credit') ||
    lower.includes('quota') ||
    lower.includes('balance') ||
    lower.includes('insufficient')
  );
}

/**
 * Mints a real-time Vidu S2-Editing (`virtual_tryon`) live streaming session.
 * Returns session-scoped `clientSecret` (for direct Vidu control WS without exposing
 * permanent `vda_` keys) + AliRTC join credentials + `renderUid`.
 */
async function handleCreateLiveSession(
  url: string,
  serviceKey: string,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const activeProvider = await getActiveTryonProvider(url, serviceKey);
  if (activeProvider !== 'vidu') {
    return respond({
      error: 'Vidu try-on is not the active provider',
      code: 'provider_not_active',
      activeProvider,
    }, 409);
  }

  const garmentImage = body.garmentImage ?? body.image_url;
  if (!isValidImageInput(garmentImage)) {
    return respond({ error: 'Valid garmentImage URL or data URI is required', code: 'invalid_input' }, 400);
  }

  const pool = (
    await resolveViduApiKeyPool(url, serviceKey, Deno.env.get('VIDU_API_KEY'))
  ).filter((k) => k.isActive);

  if (pool.length === 0) {
    return respond({ error: 'Service not configured', code: 'all_keys_depleted' }, 503);
  }

  const quota = await consumeTryonAttempt(url, serviceKey, userId);
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

  let sawDepleted = false;
  let createdData: Record<string, unknown> | null = null;
  let selectedKey: PooledViduKey | null = null;

  for (const candidate of pool) {
    const probe = await probeViduKeyCredits(candidate.apiKey, 5000);
    if (probe.status === 'invalid') {
      await updateViduKeyTelemetry(url, serviceKey, {
        id: candidate.id,
        status: 'invalid',
      });
      continue;
    }
    if (probe.status === 'depleted') {
      sawDepleted = true;
      await updateViduKeyTelemetry(url, serviceKey, {
        id: candidate.id,
        credits: 0,
        status: 'depleted',
      });
      continue;
    }
    if (probe.credits !== null) {
      await updateViduKeyTelemetry(url, serviceKey, {
        id: candidate.id,
        credits: probe.credits,
        status: probe.status,
      });
    }

    try {
      const response = await fetch(`${VIDU_HTTP_ORIGIN}/live/s_editing/realtime`, {
        method: 'POST',
        headers: {
          Authorization: `Token ${candidate.apiKey}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          image_url: garmentImage.trim(),
          editing_type: 'virtual_tryon',
        }),
        signal: AbortSignal.timeout(30000),
      });

      if (response.status === 401 || response.status === 403) {
        await updateViduKeyTelemetry(url, serviceKey, {
          id: candidate.id,
          status: 'invalid',
        });
        continue;
      }

      const rawText = await response.text();
      if (!response.ok) {
        if (looksLikeCreditError(response.status, rawText)) {
          sawDepleted = true;
          await updateViduKeyTelemetry(url, serviceKey, {
            id: candidate.id,
            credits: response.status === 402 ? 0 : undefined,
            status: 'depleted',
          });
        }
        continue;
      }

      let parsed: Record<string, unknown> | null = null;
      try {
        parsed = JSON.parse(rawText) as Record<string, unknown>;
      } catch {
        continue;
      }

      const live = parsed?.live as Record<string, unknown> | undefined;
      const rtc = parsed?.rtc as Record<string, unknown> | undefined;
      const liveId = typeof live?.id === 'string' ? live.id.trim() : '';
      const rtcToken = typeof rtc?.token === 'string' ? rtc.token.trim() : '';
      const renderUid = typeof parsed?.render_uid === 'string' ? parsed.render_uid.trim() : '';
      const clientSecret = typeof parsed?.client_secret === 'string' ? parsed.client_secret.trim() : '';

      if (liveId && rtcToken && renderUid && clientSecret) {
        createdData = parsed;
        selectedKey = candidate;
        break;
      }
    } catch {
      continue;
    }
  }

  if (!createdData || !selectedKey) {
    if (quota?.allowed) await refundTryonAttempt(url, serviceKey, userId);
    if (sawDepleted) {
      return respond({
        error: 'All configured Vidu API keys are out of credits',
        code: 'all_keys_depleted',
      }, 503);
    }
    return respond({ error: 'Unable to start Vidu live session', code: 'upstream_failed' }, 502);
  }

  const liveObj = createdData.live as Record<string, unknown>;
  const rtcObj = createdData.rtc as Record<string, unknown>;
  const liveId = String(liveObj.id).trim();
  const renderUid = String(createdData.render_uid).trim();
  const clientSecret = String(createdData.client_secret).trim();

  await Promise.all([
    updateViduKeyTelemetry(url, serviceKey, {
      id: selectedKey.id,
      markUsed: true,
    }),
    recordViduTask(url, serviceKey, {
      taskId: liveId,
      userId,
      keyId: selectedKey.id,
      state: 'waiting',
      sessionDurationSeconds,
    }),
  ]);

  return respond({
    liveId,
    clientSecret,
    renderUid,
    rtc: {
      appId: String(rtcObj.app_id ?? ''),
      channelId: String(rtcObj.channel_id ?? ''),
      userId: String(rtcObj.user_id ?? ''),
      token: String(rtcObj.token ?? ''),
      tokenExpireAt: rtcObj.token_expire_at ?? null,
    },
    sessionDurationSeconds,
    dailyLimit: quota?.daily_limit ?? 3,
    usedToday: quota?.used_today ?? 1,
    remainingToday: quota?.remaining_today ?? 2,
  });
}

/**
 * Best-effort telemetry & safe single-use refund when a live session ends
 * or fails before going live.
 */
async function handleEndLiveSession(
  url: string,
  serviceKey: string,
  userId: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const liveId = typeof body.liveId === 'string' ? body.liveId.trim() : '';
  const failedBeforeLive = body.failedBeforeLive === true;
  if (!liveId || liveId.length > 128) {
    return respond({ ok: true, refunded: false });
  }

  const stored = await getStoredViduTask(url, serviceKey, liveId, userId);
  if (!stored) {
    return respond({ ok: true, refunded: false });
  }

  const refunded = await markViduTaskState(
    url,
    serviceKey,
    liveId,
    userId,
    failedBeforeLive ? 'failed' : 'ended',
    failedBeforeLive,
  );

  // Refresh the key's remaining credits so Admin badge reflects live spend quickly.
  if (stored.key_id) {
    try {
      const pool = await resolveViduApiKeyPool(
        url,
        serviceKey,
        Deno.env.get('VIDU_API_KEY'),
      );
      const matched = pool.find((k) => k.id === stored.key_id);
      if (matched) {
        const refreshed = await probeViduKeyCredits(matched.apiKey, 5000);
        if (refreshed.credits !== null) {
          await updateViduKeyTelemetry(url, serviceKey, {
            id: matched.id,
            credits: refreshed.credits,
            status: refreshed.status,
          });
        }
      }
    } catch {}
  }

  return respond({ ok: true, refunded });
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
    if (!url || !anonKey || !serviceKey) {
      return respond({ error: 'Service not configured' }, 503);
    }

    const userRes = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: auth, apikey: anonKey },
      signal: AbortSignal.timeout(8000),
    });
    if (!userRes.ok) return respond({ error: 'Unauthorized' }, 401);
    const user = await userRes.json();
    if (!user.id || user.is_anonymous) return respond({ error: 'Unauthorized' }, 401);

    if (req.method === 'GET') {
      return await handleAdminCreditsRequest(url, serviceKey, user.id);
    }

    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const action = typeof body.action === 'string' ? body.action.toLowerCase() : 'create_live';

    if (action === 'end_live') {
      return await handleEndLiveSession(url, serviceKey, user.id, body);
    }
    return await handleCreateLiveSession(url, serviceKey, user.id, body);
  } catch {
    return respond({ error: 'Vidu try-on service unavailable' }, 503);
  }
});
