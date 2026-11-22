// Deploy with: supabase functions deploy send-push-notification --no-verify-jwt
// (Auth is verified inside the handler so BOTH Supabase Database Webhooks AND
// authenticated mobile clients can invoke it securely!)
//
// Dispatches real-time background/terminated push notifications via:
//   - FCM HTTP v1 (Android + iOS): FIREBASE_SERVICE_ACCOUNT_JSON
//   - Direct Apple APNs HTTP/2 (iOS): APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID
//
// Supported invocation modes:
//   1) Supabase Database Webhook (INSERT on public.notifications):
//      Headers: x-webhook-secret: <PUSH_WEBHOOK_SECRET> (or service_role Bearer)
//      Body: { type: "INSERT", table: "notifications", record: { id, ... } }
//   2) Authenticated client call for a specific notification:
//      Headers: Authorization: Bearer <user_jwt>
//      Body: { notification_id: "<uuid>" }
//   3) Authenticated client self-test push:
//      Headers: Authorization: Bearer <user_jwt>
//      Body: { action: "test", title?: "...", body?: "..." }

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-webhook-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const respond = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...cors,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
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
  audience: 'all' | 'customer' | 'shop' | 'admin';
  created_by: string | null;
  target_user_id: string | null;
  shop_id: string | null;
  sender_role: string | null;
  target_scope: string | null;
  metadata?: Record<string, unknown> | null;
}

interface PushTokenRow {
  id: string;
  token: string;
  platform: string;
  user_id: string;
}

function base64UrlEncode(input: Uint8Array | string): string {
  const bytes =
    typeof input === 'string' ? new TextEncoder().encode(input) : input;
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
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

  const sigBuffer = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64UrlEncode(new Uint8Array(sigBuffer))}`;
}

function isRawHexApnsToken(token: string): boolean {
  return /^[0-9a-fA-F]{64,}$/.test(token);
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
  excludeUserId: string | null,
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
    ids = Array.from(
      new Set(orders.map((o) => o.customer_id).filter(Boolean)),
    );
  } else {
    let profileFilter = 'select=id&is_active=eq.true';
    if (scope === 'all_customers' || notif.audience === 'customer') {
      profileFilter += '&role=eq.customer';
    } else if (notif.audience === 'shop') {
      profileFilter += '&role=eq.shop';
    } else if (notif.audience === 'admin') {
      profileFilter += '&role=eq.admin';
    }
    const profiles = await supabaseGet<Array<{ id: string }>>(
      baseUrl,
      serviceKey,
      `profiles?${profileFilter}`,
    );
    ids = profiles.map((p) => p.id).filter(Boolean);
  }

  const excluded = excludeUserId ?? notif.created_by;
  return excluded ? ids.filter((id) => id !== excluded) : ids;
}

function buildFlatDataPayload(notif: NotificationRow): Record<string, string> {
  const meta =
    notif.metadata && typeof notif.metadata === 'object' ? notif.metadata : {};
  const data: Record<string, string> = {
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
    notification_id: notif.id,
    title: notif.title,
    body: notif.body,
    audience: notif.audience,
    sender_role: notif.sender_role ?? 'system',
    target_scope: notif.target_scope ?? 'audience',
    shop_id: notif.shop_id ?? String(meta.shop_id ?? ''),
    route: String(meta.route ?? ''),
    event_type: String(meta.event_type ?? ''),
    order_id: String(meta.order_id ?? ''),
    product_id: String(meta.product_id ?? ''),
  };
  return data;
}

async function dispatchToUsers(
  url: string,
  serviceKey: string,
  notif: NotificationRow,
  targetUserIds: string[],
): Promise<{ sent: number; totalTokens: number; cleanedTokens: number; skipped?: boolean; reason?: string }> {
  const serviceAccountRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  const apnsKeyP8 = Deno.env.get('APNS_KEY_P8');
  const apnsKeyId = Deno.env.get('APNS_KEY_ID');
  const apnsTeamId = Deno.env.get('APNS_TEAM_ID');
  const apnsBundleId =
    Deno.env.get('APNS_BUNDLE_ID') ?? 'com.example.fashionMarketplace';
  const apnsHost =
    Deno.env.get('APNS_USE_SANDBOX') === 'true'
      ? 'https://api.sandbox.push.apple.com'
      : 'https://api.push.apple.com';

  const hasFcm = Boolean(serviceAccountRaw);
  const hasApns = Boolean(apnsKeyP8 && apnsKeyId && apnsTeamId);

  if (!hasFcm && !hasApns) {
    return {
      sent: 0,
      totalTokens: 0,
      cleanedTokens: 0,
      skipped: true,
      reason: 'Neither FCM nor APNs credentials configured',
    };
  }

  if (targetUserIds.length === 0) {
    return { sent: 0, totalTokens: 0, cleanedTokens: 0 };
  }

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
    return { sent: 0, totalTokens: 0, cleanedTokens: 0 };
  }

  let sent = 0;
  const staleTokenIds: string[] = [];
  const flatData = buildFlatDataPayload(notif);

  const serviceAccount = hasFcm
    ? (JSON.parse(serviceAccountRaw!) as ServiceAccount)
    : null;
  const fcmAccessToken = serviceAccount
    ? await getGoogleAccessToken(serviceAccount)
    : null;
  const apnsJwt = hasApns
    ? await createApnsJwt(apnsKeyP8!, apnsKeyId!, apnsTeamId!)
    : null;

  await Promise.all(
    tokens.map(async (entry) => {
      if (
        entry.platform === 'ios' &&
        isRawHexApnsToken(entry.token) &&
        apnsJwt
      ) {
        const res = await fetch(`${apnsHost}/3/device/${entry.token}`, {
          method: 'POST',
          headers: {
            authorization: `bearer ${apnsJwt}`,
            'apns-topic': apnsBundleId,
            'apns-push-type': 'alert',
            'apns-priority': '10',
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            aps: {
              alert: { title: notif.title, body: notif.body },
              sound: 'default',
              badge: 1,
              'mutable-content': 1,
            },
            ...flatData,
          }),
          signal: AbortSignal.timeout(10000),
        });
        if (res.ok) {
          sent++;
          return;
        }
        if (res.status === 410 || res.status === 400) {
          const text = await res.text().catch(() => '');
          if (
            text.includes('Unregistered') ||
            text.includes('BadDeviceToken')
          ) {
            staleTokenIds.push(entry.id);
          }
        }
        return;
      }

      if (
        serviceAccount &&
        fcmAccessToken &&
        !isRawHexApnsToken(entry.token)
      ) {
        const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
        const res = await fetch(fcmEndpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${fcmAccessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: entry.token,
              notification: { title: notif.title, body: notif.body },
              data: flatData,
              android: {
                priority: 'HIGH',
                notification: {
                  channel_id: 'shopy_notifications',
                  sound: 'default',
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  default_vibrate_timings: true,
                },
              },
              apns: {
                headers: { 'apns-priority': '10' },
                payload: {
                  aps: {
                    alert: { title: notif.title, body: notif.body },
                    sound: 'default',
                    badge: 1,
                    'mutable-content': 1,
                  },
                },
              },
            },
          }),
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

  return {
    sent,
    totalTokens: tokens.length,
    cleanedTokens: staleTokenIds.length,
  };
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') {
    return respond({ error: 'Method not allowed' }, 405);
  }

  try {
    const url = Deno.env.get('SUPABASE_URL');
    const anon = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const webhookSecret = (Deno.env.get('PUSH_WEBHOOK_SECRET') ?? '').trim();

    if (!url || !anon || !serviceKey) {
      return respond({ error: 'Service not configured' }, 503);
    }

    const payload = (await request.json().catch(() => null)) as Record<
      string,
      unknown
    > | null;
    if (!payload) {
      return respond({ error: 'Invalid JSON payload' }, 400);
    }

    // -----------------------------------------------------------------------
    // MODE 1: Supabase Database Webhook (INSERT on public.notifications)
    // Fires automatically for EVERY app event even when app is closed!
    // -----------------------------------------------------------------------
    const authHeader = (request.headers.get('Authorization') ?? '').trim();
    const providedWebhookSecret = (
      request.headers.get('x-webhook-secret') ?? ''
    ).trim();

    const isServiceRoleCall = authHeader === `Bearer ${serviceKey}`;
    const isValidWebhookCall =
      (webhookSecret.length > 0 && providedWebhookSecret === webhookSecret) ||
      isServiceRoleCall;

    if (
      isValidWebhookCall &&
      payload.record &&
      typeof payload.record === 'object'
    ) {
      const rec = payload.record as Record<string, unknown>;
      const notif: NotificationRow = {
        id: String(rec.id ?? ''),
        title: String(rec.title ?? ''),
        body: String(rec.body ?? ''),
        audience: (String(rec.audience ?? 'all') as NotificationRow['audience']),
        created_by: rec.created_by ? String(rec.created_by) : null,
        target_user_id: rec.target_user_id ? String(rec.target_user_id) : null,
        shop_id: rec.shop_id ? String(rec.shop_id) : null,
        sender_role: rec.sender_role ? String(rec.sender_role) : 'system',
        target_scope: rec.target_scope ? String(rec.target_scope) : 'audience',
        metadata:
          rec.metadata && typeof rec.metadata === 'object'
            ? (rec.metadata as Record<string, unknown>)
            : {},
      };
      if (!notif.id || !notif.title) {
        return respond({ ok: true, sent: 0, skipped: true });
      }
      const targetUserIds = await resolveTargetUserIds(
        url,
        serviceKey,
        notif,
        null,
      );
      const result = await dispatchToUsers(url, serviceKey, notif, targetUserIds);
      return respond({ ok: true, mode: 'webhook', ...result });
    }

    // -----------------------------------------------------------------------
    // Authenticated User Calls (MODE 2: specific notification | MODE 3: test)
    // -----------------------------------------------------------------------
    if (!authHeader.startsWith('Bearer ')) {
      return respond({ error: 'Unauthorized' }, 401);
    }

    const authRes = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: authHeader, apikey: anon },
      signal: AbortSignal.timeout(10000),
    });
    if (!authRes.ok) return respond({ error: 'Unauthorized' }, 401);
    const caller = await authRes.json();
    if (!caller.id || caller.is_anonymous) {
      return respond({ error: 'Unauthorized' }, 401);
    }

    // MODE 3: Self-test push notification for the logged-in user
    if (String(payload.action ?? '').toLowerCase() === 'test') {
      const hasFcm = Boolean(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON'));
      const hasApns = Boolean(
        Deno.env.get('APNS_KEY_P8') &&
          Deno.env.get('APNS_KEY_ID') &&
          Deno.env.get('APNS_TEAM_ID'),
      );
      if (!hasFcm && !hasApns) {
        return respond(
          {
            ok: false,
            error:
              'مفتاح Firebase غير مضاف على الخادم بعد (FIREBASE_SERVICE_ACCOUNT_JSON).',
          },
          503,
        );
      }

      const userTokens = await supabaseGet<PushTokenRow[]>(
        url,
        serviceKey,
        `device_push_tokens?select=id,token,platform,user_id&notifications_enabled=eq.true&user_id=eq.${encodeURIComponent(String(caller.id))}`,
      );
      if (userTokens.length === 0) {
        return respond(
          {
            ok: false,
            error:
              'لا يوجد رمز FCM مسجّل لهذا الجهاز بعد. تأكد من إضافة google-services.json أو مفاتيح Firebase في التطبيق.',
          },
          400,
        );
      }

      const delaySecs = Math.min(
        Math.max(Number(payload.delay_seconds ?? 0) || 0, 0),
        10,
      );
      const testNotif: NotificationRow = {
        id: crypto.randomUUID(),
        title: String(payload.title ?? 'إشعار تجريبي من وصلة 🔔'),
        body: String(
          payload.body ??
            'الإشعارات تعمل بنجاح حتى عند إغلاق التطبيق — اضغط لفتح التطبيق الآن.',
        ),
        audience: 'all',
        created_by: null,
        target_user_id: String(caller.id),
        shop_id: null,
        sender_role: 'system',
        target_scope: 'user',
        metadata: { event_type: 'test_push', route: '' },
      };

      const runSend = async () => {
        if (delaySecs > 0) {
          await new Promise((r) => setTimeout(r, delaySecs * 1000));
        }
        await dispatchToUsers(url, serviceKey, testNotif, [String(caller.id)]);
      };

      // Use EdgeRuntime.waitUntil so the HTTP response returns immediately and
      // the FCM push STILL fires after delaySecs even if the user closes the app!
      const edgeRuntime = (
        globalThis as unknown as {
          EdgeRuntime?: { waitUntil: (p: Promise<unknown>) => void };
        }
      ).EdgeRuntime;

      if (delaySecs > 0 && edgeRuntime?.waitUntil) {
        edgeRuntime.waitUntil(runSend());
        return respond({
          ok: true,
          mode: 'test',
          scheduled: true,
          delaySeconds: delaySecs,
          totalTokens: userTokens.length,
        });
      }

      const result = await dispatchToUsers(url, serviceKey, testNotif, [
        String(caller.id),
      ]);
      return respond({ ok: true, mode: 'test', ...result });
    }

    // MODE 2: Dispatch an existing notification_id
    const notificationId =
      typeof payload.notification_id === 'string'
        ? payload.notification_id.trim()
        : '';
    if (!notificationId) {
      return respond({ error: 'notification_id is required' }, 400);
    }

    const rows = await supabaseGet<NotificationRow[]>(
      url,
      serviceKey,
      `notifications?select=id,title,body,audience,created_by,target_user_id,shop_id,sender_role,target_scope,metadata&id=eq.${encodeURIComponent(notificationId)}&limit=1`,
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
    const isAuthorized =
      notif.created_by === caller.id || callerRole === 'admin';
    if (!isAuthorized) {
      return respond({ error: 'Forbidden' }, 403);
    }

    const targetUserIds = await resolveTargetUserIds(
      url,
      serviceKey,
      notif,
      caller.id,
    );
    const result = await dispatchToUsers(url, serviceKey, notif, targetUserIds);
    return respond({ ok: true, mode: 'client', ...result });
  } catch (err) {
    console.error('send-push-notification error:', err);
    return respond({ error: 'Push dispatch failed' }, 500);
  }
});
