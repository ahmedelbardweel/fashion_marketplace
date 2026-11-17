// Deploy with JWT verification enabled.
// Pure Supabase push dispatcher: sends directly to Apple APNs (HTTP/2) using
// APNS_KEY_P8 / APNS_KEY_ID / APNS_TEAM_ID / APNS_BUNDLE_ID secrets (no Firebase).

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const respond = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });

interface NotificationRow {
  id: string;
  title: string;
  body: string;
  audience: 'all' | 'customer' | 'shop';
  created_by: string | null;
  target_user_id: string | null;
  shop_id: string | null;
  sender_role: string | null;
  target_scope: string | null;
}

interface PushTokenRow {
  id: string;
  token: string;
  platform: string;
  user_id: string;
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function createApnsJwt(
  p8Pem: string,
  keyId: string,
  teamId: string,
): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: 'ES256', kid: keyId }));
  const claims = base64UrlEncode(JSON.stringify({ iss: teamId, iat }));
  const signingInput = `${header}.${claims}`;

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(p8Pem),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );

  // WebCrypto ECDSA returns IEEE P1363 raw (r || s) 64-byte signature,
  // which is the exact format required by ES256 JWS.
  const sigBuffer = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64UrlEncode(new Uint8Array(sigBuffer))}`;
}

async function supabaseGet<T>(
  baseUrl: string,
  serviceKey: string,
  pathAndQuery: string,
): Promise<T> {
  const res = await fetch(`${baseUrl}/rest/v1/${pathAndQuery}`, {
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
    },
    signal: AbortSignal.timeout(10000),
  });
  if (!res.ok) {
    throw new Error(`Supabase REST error ${res.status}`);
  }
  return (await res.json()) as T;
}

async function resolveTargetUserIds(
  baseUrl: string,
  serviceKey: string,
  notif: NotificationRow,
  callerId: string,
): Promise<string[]> {
  if (notif.target_user_id) {
    return [notif.target_user_id];
  }

  const scope = notif.target_scope ?? 'audience';
  let ids: string[] = [];

  if (scope === 'shop_customers' && notif.shop_id) {
    const orders = await supabaseGet<Array<{ customer_id: string }>>(
      baseUrl,
      serviceKey,
      `orders?select=customer_id&shop_id=eq.${encodeURIComponent(notif.shop_id)}`,
    );
    ids = Array.from(new Set(orders.map((o) => o.customer_id).filter(Boolean)));
  } else {
    let profileFilter = 'select=id&is_active=eq.true';
    if (scope === 'all_customers' || notif.audience === 'customer') {
      profileFilter += '&role=eq.customer';
    } else if (notif.audience === 'shop') {
      profileFilter += '&role=eq.shop';
    }
    const profiles = await supabaseGet<Array<{ id: string }>>(
      baseUrl,
      serviceKey,
      `profiles?${profileFilter}`,
    );
    ids = profiles.map((p) => p.id).filter(Boolean);
  }

  return ids.filter((id) => id !== callerId);
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') return respond({ error: 'Method not allowed' }, 405);

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    return respond({ error: 'Unauthorized' }, 401);
  }

  try {
    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anon || !serviceKey) {
      return respond({ error: 'Service not configured' }, 503);
    }

    const authRes = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: authorization, apikey: anon },
      signal: AbortSignal.timeout(10000),
    });
    if (!authRes.ok) return respond({ error: 'Unauthorized' }, 401);
    const caller = await authRes.json();
    if (!caller.id || caller.is_anonymous) {
      return respond({ error: 'Unauthorized' }, 401);
    }

    const payload = await request.json().catch(() => null);
    const notificationId = typeof payload?.notification_id === 'string'
      ? payload.notification_id.trim()
      : '';
    if (!notificationId) {
      return respond({ error: 'notification_id is required' }, 400);
    }

    const rows = await supabaseGet<NotificationRow[]>(
      url,
      serviceKey,
      `notifications?select=id,title,body,audience,created_by,target_user_id,shop_id,sender_role,target_scope&id=eq.${encodeURIComponent(notificationId)}&limit=1`,
    );
    const notif = rows[0];
    if (!notif) {
      return respond({ error: 'Notification not found' }, 404);
    }

    const callerProfiles = await supabaseGet<Array<{ role: string }>>(
      url,
      serviceKey,
      `profiles?select=role&id=eq.${encodeURIComponent(caller.id)}&limit=1`,
    );
    const callerRole = callerProfiles[0]?.role;
    const isAuthorized = notif.created_by === caller.id || callerRole === 'admin';
    if (!isAuthorized) {
      return respond({ error: 'Forbidden' }, 403);
    }

    const apnsKeyP8 = Deno.env.get('APNS_KEY_P8');
    const apnsKeyId = Deno.env.get('APNS_KEY_ID');
    const apnsTeamId = Deno.env.get('APNS_TEAM_ID');
    const apnsBundleId =
      Deno.env.get('APNS_BUNDLE_ID') ?? 'com.example.fashionMarketplace';
    const apnsHost = Deno.env.get('APNS_USE_SANDBOX') === 'true'
      ? 'https://api.sandbox.push.apple.com'
      : 'https://api.push.apple.com';

    if (!apnsKeyP8 || !apnsKeyId || !apnsTeamId) {
      return respond({
        ok: true,
        sent: 0,
        skipped: true,
        reason: 'APNs secrets not configured',
      });
    }

    const targetUserIds = await resolveTargetUserIds(url, serviceKey, notif, caller.id);
    if (targetUserIds.length === 0) {
      return respond({ ok: true, sent: 0, totalTokens: 0 });
    }

    const iosTokens: PushTokenRow[] = [];
    const chunkSize = 50;
    for (let i = 0; i < targetUserIds.length; i += chunkSize) {
      const chunk = targetUserIds.slice(i, i + chunkSize).join(',');
      const batch = await supabaseGet<PushTokenRow[]>(
        url,
        serviceKey,
        `device_push_tokens?select=id,token,platform,user_id&platform=eq.ios&notifications_enabled=eq.true&user_id=in.(${chunk})`,
      );
      iosTokens.push(...batch);
    }

    if (iosTokens.length === 0) {
      return respond({ ok: true, sent: 0, totalTokens: 0 });
    }

    const jwt = await createApnsJwt(apnsKeyP8, apnsKeyId, apnsTeamId);
    let sent = 0;
    const staleTokenIds: string[] = [];

    await Promise.all(
      iosTokens.map(async (entry) => {
        const res = await fetch(`${apnsHost}/3/device/${entry.token}`, {
          method: 'POST',
          headers: {
            authorization: `bearer ${jwt}`,
            'apns-topic': apnsBundleId,
            'apns-push-type': 'alert',
            'apns-priority': '10',
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            aps: {
              alert: {
                title: notif.title,
                body: notif.body,
              },
              sound: 'default',
              badge: 1,
            },
            notification_id: notif.id,
            audience: notif.audience,
            sender_role: notif.sender_role ?? 'system',
            target_scope: notif.target_scope ?? 'audience',
          }),
          signal: AbortSignal.timeout(10000),
        });

        if (res.ok) {
          sent++;
          return;
        }

        if (res.status === 410 || res.status === 400) {
          const text = await res.text().catch(() => '');
          if (text.includes('Unregistered') || text.includes('BadDeviceToken')) {
            staleTokenIds.push(entry.id);
          }
        }
      }),
    );

    if (staleTokenIds.length > 0) {
      await fetch(
        `${url}/rest/v1/device_push_tokens?id=in.(${staleTokenIds.join(',')})`,
        {
          method: 'DELETE',
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
          },
          signal: AbortSignal.timeout(10000),
        },
      ).catch(() => {});
    }

    return respond({
      ok: true,
      sent,
      totalTokens: iosTokens.length,
      cleanedTokens: staleTokenIds.length,
    });
  } catch {
    return respond({ error: 'Push dispatch failed' }, 500);
  }
});
