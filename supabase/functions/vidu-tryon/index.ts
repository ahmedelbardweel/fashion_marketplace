import NodeWebSocket from 'npm:ws@8';
import {
  PooledViduKey,
  resolveViduApiKeyPool,
  updateViduKeyTelemetry,
} from './secret_resolver.ts';

const VIDU_HOST = 'api.vidu.com';
const VIDU_HTTP_ORIGIN = `https://${VIDU_HOST}`;
const VIDU_WS_ORIGIN = `wss://${VIDU_HOST}`;
const VIDU_ENT_BASE = `${VIDU_HTTP_ORIGIN}/ent/v2`;
const MAX_SIGNAL_BYTES = 6 * 1024 * 1024;

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
  client_secret?: string | null;
  session_duration_seconds?: number | null;
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
    clientSecret?: string | null;
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
        p_client_secret: params.clientSecret ?? null,
        p_session_duration_seconds: params.sessionDurationSeconds ?? 30,
      }),
      signal: AbortSignal.timeout(5000),
    });
    // Fallback for migration 041 without migration 042 parameters.
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
 * Creates a real-time Vidu S2-Editing (`virtual_tryon`) live streaming session.
 * POST https://api.vidu.com/live/s_editing/realtime
 * Returns AliRTC join credentials + render_uid; keeps API key & client_secret on server.
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

      if (liveId && rtcToken && renderUid) {
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
  const clientSecret =
    typeof createdData.client_secret === 'string' && createdData.client_secret.trim()
      ? createdData.client_secret.trim()
      : null;

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
      clientSecret,
      sessionDurationSeconds,
    }),
  ]);

  return respond({
    liveId,
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
 * Authenticated WebSocket control bridge between Flutter client and Vidu S2-Editing WS:
 *   wss://api.vidu.com/live/ws/live/connect?live_id=...&conn_id=...[&client_secret=...]
 * Keeps the Vidu API key and client_secret strictly on the server, handles conn_init,
 * live switch_prompt (mid-stream garment changes), server-side duration cap, and hangup.
 */
async function handleLiveControlWebSocket(
  req: Request,
  url: string,
  serviceKey: string,
  userId: string,
): Promise<Response> {
  const reqUrl = new URL(req.url);
  const liveId = reqUrl.searchParams.get('live_id')?.trim() ?? '';
  if (!liveId || liveId.length > 128) {
    return respond({ error: 'Missing live_id' }, 400);
  }

  const stored = await getStoredViduTask(url, serviceKey, liveId, userId);
  if (!stored) {
    return respond({ error: 'Live session not found' }, 404);
  }

  const pool = await resolveViduApiKeyPool(
    url,
    serviceKey,
    Deno.env.get('VIDU_API_KEY'),
  );
  const matchedKey =
    (stored.key_id ? pool.find((k) => k.id === stored.key_id) : null) ??
    pool.find((k) => k.isActive) ??
    pool[0];

  if (!matchedKey) {
    return respond({ error: 'Service not configured' }, 503);
  }

  const maxDurationSec = Math.min(
    Math.max(Number(stored.session_duration_seconds ?? 30), 10),
    300,
  );

  const { socket: client, response } = Deno.upgradeWebSocket(req);

  const connId = crypto.randomUUID();
  let seqId = 0;
  let closed = false;
  let ready = false;
  let hangupSent = false;
  let initTimer: number | undefined;
  let sessionTimer: number | undefined;
  let remote: NodeWebSocket | null = null;

  const sendClient = (payload: Record<string, unknown>) => {
    try {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify(payload));
      }
    } catch {
      // Ignore send errors on closing socket.
    }
  };

  const sendSignal = (type: number, payload: Record<string, unknown>) => {
    try {
      if (remote && remote.readyState === NodeWebSocket.OPEN) {
        remote.send(
          JSON.stringify({
            type,
            live_id: liveId,
            conn_id: connId,
            seq_id: ++seqId,
            payload,
          }),
        );
      }
    } catch {
      // Ignore write failures on closing socket.
    }
  };

  const shutdown = (closeClient: boolean, sendHangup: boolean, reason = 'user_end') => {
    if (closed) return;
    if (sendHangup && !hangupSent) {
      sendSignal(5, { hangup: { hangup_reason: reason } });
      hangupSent = true;
    }
    closed = true;
    if (initTimer !== undefined) clearTimeout(initTimer);
    if (sessionTimer !== undefined) clearTimeout(sessionTimer);

    try {
      if (remote && remote.readyState < NodeWebSocket.CLOSING) {
        remote.close(1000, 'session ended');
      }
    } catch {}
    try {
      if (closeClient && client.readyState < WebSocket.CLOSING) {
        client.close(1000, 'session ended');
      }
    } catch {}

    // Best-effort credit telemetry refresh & refund if session never went live.
    (async () => {
      try {
        if (!ready) {
          await markViduTaskState(url, serviceKey, liveId, userId, 'failed', true);
        } else {
          await markViduTaskState(url, serviceKey, liveId, userId, 'ended', false);
          const refreshed = await probeViduKeyCredits(matchedKey.apiKey, 5000);
          if (refreshed.credits !== null) {
            await updateViduKeyTelemetry(url, serviceKey, {
              id: matchedKey.id,
              credits: refreshed.credits,
              status: refreshed.status,
            });
          }
        }
      } catch {}
    })();
  };

  const fail = (message: string, code = 'session_failed') => {
    if (closed) return;
    sendClient({ event: 'fatal', code, message });
    shutdown(true, true);
  };

  client.onopen = () => {
    const query = new URLSearchParams({ live_id: liveId, conn_id: connId });
    if (stored.client_secret) {
      query.set('client_secret', stored.client_secret);
    }

    initTimer = setTimeout(() => {
      fail('انتهت مهلة تجهيز البث المباشر. يرجى المحاولة مجدداً.', 'init_timeout');
    }, 90000);

    try {
      remote = new NodeWebSocket(`${VIDU_WS_ORIGIN}/live/ws/live/connect?${query}`, {
        headers: { Authorization: `Token ${matchedKey.apiKey}` },
        handshakeTimeout: 15000,
        maxPayload: MAX_SIGNAL_BYTES,
      });
    } catch {
      fail('تعذر الاتصال بخادم البث المباشر.', 'ws_connect_failed');
      return;
    }

    remote.on('open', () => {
      if (closed) return;
      sendClient({ event: 'remote_open' });
      sendSignal(1, { conn_init: { version: 1 } });
    });

    remote.on('message', (rawData: unknown) => {
      if (closed) return;
      const text = typeof rawData === 'string'
        ? rawData
        : (rawData instanceof Uint8Array
          ? new TextDecoder().decode(rawData)
          : String(rawData));
      let msg: Record<string, unknown>;
      try {
        msg = JSON.parse(text) as Record<string, unknown>;
      } catch {
        return;
      }

      const msgType = Number(msg.type);
      const payload = (msg.payload && typeof msg.payload === 'object')
        ? (msg.payload as Record<string, unknown>)
        : {};

      if (msgType === 2 && payload.conn_init_ack && typeof payload.conn_init_ack === 'object') {
        const ack = payload.conn_init_ack as Record<string, unknown>;
        if (ack.success === true) {
          if (initTimer !== undefined) clearTimeout(initTimer);
          ready = true;
          markViduTaskState(url, serviceKey, liveId, userId, 'on_live', false);
          sendClient({ event: 'on_live' });
          // Hard server-side session duration cap matching Admin cost controls.
          sessionTimer = setTimeout(() => {
            sendClient({ event: 'server_hangup', reason: 'timeout' });
            shutdown(true, true, 'timeout');
          }, (maxDurationSec + 5) * 1000);
        } else if (ack.error_code === 'NOT_READY') {
          sendClient({ event: 'not_ready' });
        } else {
          fail(
            typeof ack.error_msg === 'string' && ack.error_msg
              ? ack.error_msg
              : 'فشل بدء جلسة البث المباشر.',
            String(ack.error_code ?? 'conn_init_failed'),
          );
        }
        return;
      }

      if (msgType === 6) {
        const hangup = (payload.hangup && typeof payload.hangup === 'object')
          ? (payload.hangup as Record<string, unknown>)
          : {};
        const reason = String(hangup.hangup_reason ?? 'server_closed');
        sendClient({ event: 'server_hangup', reason });
        shutdown(true, false);
        return;
      }

      if (msgType === 14 && payload.switch_prompt_ack && typeof payload.switch_prompt_ack === 'object') {
        const ack = payload.switch_prompt_ack as Record<string, unknown>;
        if (ack.success === false) {
          sendClient({
            event: 'switch_prompt_error',
            code: String(ack.error_code ?? 'switch_failed'),
            message: String(ack.error_msg ?? 'تعذر تبديل القطعة'),
          });
        }
      }
    });

    remote.on('close', () => {
      if (!closed) {
        sendClient({ event: 'remote_closed' });
        shutdown(true, false);
      }
    });

    remote.on('error', () => {
      fail('انقطع الاتصال بخادم البث المباشر.', 'remote_error');
    });
  };

  client.onmessage = (event) => {
    if (closed) return;
    let msg: Record<string, unknown>;
    try {
      msg = JSON.parse(typeof event.data === 'string' ? event.data : '') as Record<string, unknown>;
    } catch {
      return;
    }

    const action = typeof msg.action === 'string' ? msg.action : '';
    if (action === 'hangup') {
      shutdown(true, true, 'user_end');
      return;
    }
    if (action === 'switch_prompt') {
      if (!ready) {
        sendClient({ event: 'action_error', message: 'الجلسة غير جاهزة بعد.' });
        return;
      }
      const imageUrl = msg.image_url;
      if (!isValidImageInput(imageUrl)) {
        sendClient({ event: 'action_error', message: 'رابط صورة القطعة غير صالح.' });
        return;
      }
      sendSignal(13, {
        switch_prompt: {
          prompts: [{ type: 'image', content: imageUrl.trim() }],
          editing_type: 'virtual_tryon',
        },
      });
      sendClient({ event: 'switch_prompt_sent' });
    }
  };

  client.onclose = () => shutdown(false, true);
  client.onerror = () => shutdown(false, true);

  return response;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST' && req.method !== 'GET') {
    return respond({ error: 'Method not allowed' }, 405);
  }
  try {
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anonKey || !serviceKey) {
      return respond({ error: 'Service not configured' }, 503);
    }

    const reqUrl = new URL(req.url);
    const headerAuth = req.headers.get('Authorization');
    const queryToken = reqUrl.searchParams.get('access_token')?.trim();
    const auth = headerAuth?.startsWith('Bearer ')
      ? headerAuth
      : (queryToken ? `Bearer ${queryToken}` : null);
    if (!auth) return respond({ error: 'Unauthorized' }, 401);

    const userRes = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: auth, apikey: anonKey },
      signal: AbortSignal.timeout(8000),
    });
    if (!userRes.ok) return respond({ error: 'Unauthorized' }, 401);
    const user = await userRes.json();
    if (!user.id || user.is_anonymous) return respond({ error: 'Unauthorized' }, 401);

    // WebSocket upgrade for real-time Vidu S2-Editing control plane.
    const upgrade = req.headers.get('upgrade')?.toLowerCase() ?? '';
    if (req.method === 'GET' && upgrade === 'websocket') {
      return await handleLiveControlWebSocket(req, url, serviceKey, user.id);
    }

    // Admin aggregated live credits across all Vidu keys via standard GET.
    if (req.method === 'GET') {
      return await handleAdminCreditsRequest(url, serviceKey, user.id);
    }

    const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    return await handleCreateLiveSession(url, serviceKey, user.id, body);
  } catch {
    return respond({ error: 'Vidu try-on service unavailable' }, 503);
  }
});
