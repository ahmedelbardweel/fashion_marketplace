// Deploy with JWT verification enabled. Dispatches FCM HTTP v1 push notifications
// for authoritative rows in public.notifications using FIREBASE_SERVICE_ACCOUNT_JSON.

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

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

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
    .replace(/\s+/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getGoogleAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64UrlEncode(
    JSON.stringify({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const signingInput = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
    signal: AbortSignal.timeout(10000),
  });
  if (!tokenRes.ok) {
    throw new Error(`OAuth token error: ${tokenRes.status}`);
  }
  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) {
    throw new Error('Missing access_token from Google OAuth');
  }
  return tokenJson.access_token as string;
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

  // Do not push broadcast back to the sender's own account.
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

    // Verify caller owns the notification or is an admin.
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

    const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountRaw) {
      return respond({
        ok: true,
        sent: 0,
        skipped: true,
        reason: 'FIREBASE_SERVICE_ACCOUNT_JSON not configured',
      });
    }

    const serviceAccount = JSON.parse(serviceAccountRaw) as ServiceAccount;
    const targetUserIds = await resolveTargetUserIds(url, serviceKey, notif, caller.id);
    if (targetUserIds.length === 0) {
      return respond({ ok: true, sent: 0, totalTokens: 0 });
    }

    // Fetch enabled device tokens in chunks to keep query URLs compact.
    const tokens: PushTokenRow[] = [];
    const chunkSize = 50;
    for (let i = 0; i < targetUserIds.length; i += chunkSize) {
      const chunk = targetUserIds.slice(i, i + chunkSize).join(',');
      const batch = await supabaseGet<PushTokenRow[]>(
        url,
        serviceKey,
        `device_push_tokens?select=id,token,platform,user_id&notifications_enabled=eq.true&user_id=in.(${chunk})`,
      );
      tokens.push(...batch);
    }

    if (tokens.length === 0) {
      return respond({ ok: true, sent: 0, totalTokens: 0 });
    }

    const accessToken = await getGoogleAccessToken(serviceAccount);
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    let sent = 0;
    const staleTokenIds: string[] = [];

    await Promise.all(
      tokens.map(async (entry) => {
        const messageBody = {
          message: {
            token: entry.token,
            notification: {
              title: notif.title,
              body: notif.body,
            },
            data: {
              notification_id: notif.id,
              audience: notif.audience,
              sender_role: notif.sender_role ?? 'system',
              target_scope: notif.target_scope ?? 'audience',
              shop_id: notif.shop_id ?? '',
            },
            android: {
              priority: 'HIGH',
              notification: {
                channel_id: 'shopy_notifications',
                sound: 'default',
              },
            },
            apns: {
              headers: {
                'apns-priority': '10',
              },
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          },
        };

        const res = await fetch(fcmEndpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(messageBody),
          signal: AbortSignal.timeout(10000),
        });

        if (res.ok) {
          sent++;
          return;
        }

        const errText = await res.text().catch(() => '');
        if (errText.includes('UNREGISTERED') || errText.includes('NOT_FOUND')) {
          staleTokenIds.push(entry.id);
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
      totalTokens: tokens.length,
      cleanedTokens: staleTokenIds.length,
    });
  } catch {
    return respond({ error: 'Push dispatch failed' }, 500);
  }
});
