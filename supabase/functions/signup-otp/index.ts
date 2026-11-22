// Deploy with: supabase functions deploy signup-otp --no-verify-jwt
//
// Pre-registration Email OTP verification so NO row is created in auth.users,
// public.profiles, or public.shops until the user proves email ownership with
// a valid 6-digit OTP.
//
// Required Edge Function secrets (choose SMTP OR Resend):
//   Option A — Gmail / Custom SMTP (recommended if already using Gmail App Password):
//     SMTP_HOST=smtp.gmail.com
//     SMTP_PORT=465
//     SMTP_USER=your-email@gmail.com
//     SMTP_PASS=your-16-char-app-password
//     SMTP_FROM=your-email@gmail.com          (optional, defaults to SMTP_USER)
//     SMTP_SENDER_NAME=وصلة | Wasla           (optional)
//
//   Option B — Resend HTTP API:
//     RESEND_API_KEY=re_xxxxxxxxx
//     RESEND_FROM=وصلة <onboarding@yourdomain.com>

import nodemailer from 'npm:nodemailer@6.9.16';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
  'Cache-Control': 'no-store',
};

const respond = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: cors });

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const OTP_RE = /^\d{6}$/;
const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
const RESEND_COOLDOWN_MS = 60 * 1000; // 60 seconds
const HOURLY_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const MAX_SENDS_PER_HOUR = 5;
const MAX_VERIFY_ATTEMPTS = 5;

interface PendingOtpRow {
  email: string;
  code_hash: string;
  salt: string;
  expires_at: string;
  attempts: number;
  resend_count: number;
  window_started_at: string;
  last_sent_at: string;
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

function generateSixDigitOtp(): string {
  // Rejection sampling avoids modulo bias across 0..999999.
  const limit = Math.floor(0x100000000 / 1_000_000) * 1_000_000;
  const buf = new Uint32Array(1);
  while (true) {
    crypto.getRandomValues(buf);
    if (buf[0] < limit) {
      return String(buf[0] % 1_000_000).padStart(6, '0');
    }
  }
}

function generateSalt(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return toHex(bytes);
}

async function hashOtp(salt: string, code: string): Promise<string> {
  const data = new TextEncoder().encode(`${salt}:${code}`);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return toHex(new Uint8Array(digest));
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function buildBrandedOtpHtml(
  code: string,
  appLogoUrl: string,
  mode: 'signup' | 'login' = 'signup',
): string {
  const isLogin = mode === 'login';
  const heading = isLogin ? 'تأكيد تسجيل الدخول' : 'تأكيد بريدك الإلكتروني';
  const lead = isLogin
    ? 'تم رصد تسجيل دخول لأول مرة على هذا الجهاز في <strong>وصلة</strong>. أدخل رمز التحقق التالي داخل التطبيق للمتابعة:'
    : 'مرحباً بك في <strong>وصلة</strong>! أدخل رمز التحقق التالي داخل التطبيق لإتمام إنشاء حسابك:';
  const ignoreNote = isLogin
    ? 'إذا لم تحاول تسجيل الدخول الآن، ننصحك بتغيير كلمة المرور فوراً لحماية حسابك.'
    : 'إذا لم تطلب إنشاء حساب جديد في تطبيق وصلة، يمكنك تجاهل هذه الرسالة بأمان ولن يتم إنشاء أي حساب.';

  const logoHtml = appLogoUrl
    ? `<img src="${appLogoUrl}" alt="Wasla" width="48" height="48" style="display:block;border-radius:12px;" />`
    : `<div style="width:48px;height:48px;border-radius:12px;background:#007C83;color:#ffffff;font-size:22px;font-weight:800;line-height:48px;text-align:center;">و</div>`;

  const digitCells = code
    .split('')
    .map(
      (d) =>
        `<td style="padding:0 4px;">
          <div style="width:44px;height:52px;line-height:52px;text-align:center;background:#F4F8F8;border:1.5px solid #B8E1DF;border-radius:12px;font-size:26px;font-weight:800;color:#0F172A;font-family:'SFMono-Regular',Consolas,'Liberation Mono',Menlo,monospace;">${d}</div>
        </td>`,
    )
    .join('');

  return `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${heading} — وصلة</title>
</head>
<body style="margin:0;padding:0;background-color:#F4F6F8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Tahoma,Arial,sans-serif;color:#111827;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#F4F6F8;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:#FFFFFF;border-radius:20px;overflow:hidden;border:1px solid #E5E7EB;box-shadow:0 8px 28px rgba(15,23,42,0.06);">
          <tr>
            <td style="background:linear-gradient(135deg,#00666C 0%,#008D94 100%);padding:28px 32px;text-align:center;">
              <table role="presentation" align="center" cellspacing="0" cellpadding="0">
                <tr>
                  <td align="center" style="background:rgba(255,255,255,0.14);padding:10px;border-radius:16px;">
                    ${logoHtml}
                  </td>
                </tr>
              </table>
              <div style="margin-top:12px;font-size:20px;font-weight:800;color:#FFFFFF;letter-spacing:0.3px;">وصلة &nbsp;|&nbsp; Wasla</div>
              <div style="margin-top:4px;font-size:13px;color:rgba(255,255,255,0.86);">سوق الأزياء العصري بالتجربة الافتراضية</div>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 28px 24px 28px;text-align:center;">
              <h1 style="margin:0 0 10px 0;font-size:22px;font-weight:800;color:#111827;">${heading}</h1>
              <p style="margin:0 0 24px 0;font-size:15px;line-height:1.7;color:#4B5563;">
                ${lead}
              </p>
              <table role="presentation" align="center" cellspacing="0" cellpadding="0" dir="ltr" style="margin:0 auto 24px auto;">
                <tr>
                  ${digitCells}
                </tr>
              </table>
              <div style="display:inline-block;padding:8px 16px;background:#FEF3C7;border:1px solid #FDE68A;border-radius:999px;font-size:12.5px;font-weight:600;color:#92400E;">
                صالح لمدة 10 دقائق فقط — لا تشارك هذا الرمز مع أي شخص
              </div>
              <p style="margin:24px 0 0 0;font-size:13px;line-height:1.65;color:#6B7280;">
                ${ignoreNote}
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:18px 28px;background:#F9FAFB;border-top:1px solid #F3F4F6;text-align:center;font-size:12px;color:#9CA3AF;">
              © ${new Date().getFullYear()} Wasla Fashion Marketplace. جميع الحقوق محفوظة.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

async function sendOtpEmail(
  toEmail: string,
  code: string,
  mode: 'signup' | 'login' = 'signup',
): Promise<void> {
  const isLogin = mode === 'login';
  const subject = isLogin
    ? `رمز تأكيد تسجيل الدخول في وصلة: ${code}`
    : `رمز تأكيد حسابك في وصلة: ${code}`;
  const text = isLogin
    ? `رمز تأكيد تسجيل الدخول الخاص بك في تطبيق وصلة هو: ${code}\nصالح لمدة 10 دقائق فقط. لا تشارك هذا الرمز مع أي شخص.`
    : `رمز التحقق الخاص بك في تطبيق وصلة هو: ${code}\nصالح لمدة 10 دقائق فقط. لا تشارك هذا الرمز مع أي شخص.`;
  const appLogoUrl = (Deno.env.get('APP_LOGO_URL') ?? '').trim();
  const html = buildBrandedOtpHtml(code, appLogoUrl, mode);

  const resendApiKey = (Deno.env.get('RESEND_API_KEY') ?? '').trim();
  if (resendApiKey) {
    const resendFrom =
      (Deno.env.get('RESEND_FROM') ?? '').trim() || 'Wasla <onboarding@resend.dev>';
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: resendFrom,
        to: [toEmail],
        subject,
        html,
        text,
      }),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      throw new Error(`RESEND_FAILED:${res.status}:${detail}`);
    }
    return;
  }

  const smtpUser = (Deno.env.get('SMTP_USER') ?? '').trim();
  const smtpPass = (Deno.env.get('SMTP_PASS') ?? '').trim();
  const smtpHost = (Deno.env.get('SMTP_HOST') ?? 'smtp.gmail.com').trim();
  const smtpPort = Number((Deno.env.get('SMTP_PORT') ?? '465').trim()) || 465;
  const smtpFrom = (Deno.env.get('SMTP_FROM') ?? smtpUser).trim();
  const senderName = (Deno.env.get('SMTP_SENDER_NAME') ?? 'وصلة | Wasla').trim();

  if (!smtpUser || !smtpPass) {
    throw new Error('EMAIL_PROVIDER_NOT_CONFIGURED');
  }

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  await transporter.sendMail({
    from: `"${senderName}" <${smtpFrom}>`,
    to: toEmail,
    subject,
    text,
    html,
  });
}

async function checkEmailExists(
  supabaseUrl: string,
  serviceKey: string,
  email: string,
): Promise<boolean> {
  const res = await fetch(`${supabaseUrl}/rest/v1/rpc/auth_email_exists`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ p_email: email }),
  });
  if (!res.ok) {
    const txt = await res.text().catch(() => '');
    throw new Error(`CHECK_EMAIL_FAILED:${res.status}:${txt}`);
  }
  const data = await res.json();
  return data === true;
}

async function checkPhoneExists(
  supabaseUrl: string,
  serviceKey: string,
  phone: string,
): Promise<boolean> {
  const cleanPhone = phone.trim();
  if (!cleanPhone) return false;
  const res = await fetch(`${supabaseUrl}/rest/v1/rpc/phone_number_exists`, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ p_phone: cleanPhone, p_exclude_user_id: null }),
  });
  if (!res.ok) {
    const txt = await res.text().catch(() => '');
    throw new Error(`CHECK_PHONE_FAILED:${res.status}:${txt}`);
  }
  const data = await res.json();
  return data === true;
}

async function getPendingOtp(
  supabaseUrl: string,
  serviceKey: string,
  email: string,
): Promise<PendingOtpRow | null> {
  const res = await fetch(
    `${supabaseUrl}/rest/v1/pending_email_otps?email=eq.${encodeURIComponent(email)}&limit=1`,
    {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    },
  );
  if (!res.ok) return null;
  const rows = (await res.json()) as PendingOtpRow[];
  return rows[0] ?? null;
}

async function deletePendingOtp(
  supabaseUrl: string,
  serviceKey: string,
  email: string,
): Promise<void> {
  await fetch(
    `${supabaseUrl}/rest/v1/pending_email_otps?email=eq.${encodeURIComponent(email)}`,
    {
      method: 'DELETE',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    },
  );
}

async function cleanupExpiredOtps(
  supabaseUrl: string,
  serviceKey: string,
): Promise<void> {
  const cutoff = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  await fetch(
    `${supabaseUrl}/rest/v1/pending_email_otps?expires_at=lt.${encodeURIComponent(cutoff)}`,
    {
      method: 'DELETE',
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    },
  ).catch(() => {});
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors });
  }
  if (req.method !== 'POST') {
    return respond({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!supabaseUrl || !serviceKey) {
    return respond({ error: 'إعدادات الخادم غير مكتملة' }, 500);
  }

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return respond({ error: 'طلب غير صالح' }, 400);
  }

  const action = String(body.action ?? '').trim().toLowerCase();
  const email = String(body.email ?? '').trim().toLowerCase();

  if (!email || !EMAIL_RE.test(email)) {
    return respond({ error: 'يرجى إدخال بريد إلكتروني صحيح' }, 400);
  }

  // =========================================================================
  //  ACTION 1: SEND / RESEND OTP (Does NOT touch auth.users / profiles / shops)
  // =========================================================================
  if (action === 'send' || action === 'resend') {
    try {
      await cleanupExpiredOtps(supabaseUrl, serviceKey);

      const exists = await checkEmailExists(supabaseUrl, serviceKey, email);
      if (exists) {
        return respond({ error: 'هذا البريد الإلكتروني مسجل مسبقاً' }, 409);
      }

      const phone = String(body.phone ?? '').trim();
      if (phone) {
        const phoneTaken = await checkPhoneExists(supabaseUrl, serviceKey, phone);
        if (phoneTaken) {
          return respond({ error: 'رقم الهاتف مسجل مسبقاً لحساب آخر' }, 409);
        }
      }

      const now = Date.now();
      const existing = await getPendingOtp(supabaseUrl, serviceKey, email);
      let resendCount = 1;
      let windowStartedAt = new Date(now).toISOString();

      if (existing) {
        const lastSentMs = Date.parse(existing.last_sent_at);
        if (!Number.isNaN(lastSentMs)) {
          const elapsed = now - lastSentMs;
          if (elapsed < RESEND_COOLDOWN_MS) {
            const waitSecs = Math.ceil((RESEND_COOLDOWN_MS - elapsed) / 1000);
            return respond(
              {
                error: `يرجى الانتظار ${waitSecs} ثانية قبل طلب رمز تحقق جديد.`,
                retry_after: waitSecs,
              },
              429,
            );
          }
        }

        const windowStartMs = Date.parse(existing.window_started_at);
        if (!Number.isNaN(windowStartMs) && now - windowStartMs < HOURLY_WINDOW_MS) {
          if (existing.resend_count >= MAX_SENDS_PER_HOUR) {
            return respond(
              {
                error: 'تم تجاوز الحد الأقصى لطلب رموز التحقق. حاول بعد ساعة.',
              },
              429,
            );
          }
          resendCount = existing.resend_count + 1;
          windowStartedAt = existing.window_started_at;
        }
      }

      const code = generateSixDigitOtp();
      const salt = generateSalt();
      const codeHash = await hashOtp(salt, code);
      const expiresAt = new Date(now + OTP_TTL_MS).toISOString();
      const nowIso = new Date(now).toISOString();

      const upsertRes = await fetch(
        `${supabaseUrl}/rest/v1/pending_email_otps?on_conflict=email`,
        {
          method: 'POST',
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            'Content-Type': 'application/json',
            Prefer: 'resolution=merge-duplicates',
          },
          body: JSON.stringify({
            email,
            code_hash: codeHash,
            salt,
            expires_at: expiresAt,
            attempts: 0,
            resend_count: resendCount,
            window_started_at: windowStartedAt,
            last_sent_at: nowIso,
          }),
        },
      );
      if (!upsertRes.ok) {
        const detail = await upsertRes.text().catch(() => '');
        console.error('Upsert pending_email_otps failed:', upsertRes.status, detail);
        return respond({ error: 'تعذر تجهيز رمز التحقق. حاول مجدداً.' }, 500);
      }

      try {
        await sendOtpEmail(email, code);
      } catch (mailErr) {
        // Roll back pending OTP if email delivery failed so the user can retry immediately.
        await deletePendingOtp(supabaseUrl, serviceKey, email).catch(() => {});
        const msg = mailErr instanceof Error ? mailErr.message : String(mailErr);
        console.error('sendOtpEmail failed:', msg);
        if (msg === 'EMAIL_PROVIDER_NOT_CONFIGURED') {
          return respond(
            {
              error:
                'خدمة إرسال البريد غير مُعدّة على الخادم بعد (SMTP_USER / SMTP_PASS أو RESEND_API_KEY).',
            },
            503,
          );
        }
        return respond(
          { error: 'تعذر إرسال رسالة رمز التحقق. تحقق من البريد وحاول مجدداً.' },
          502,
        );
      }

      return respond({ ok: true, expires_in_seconds: OTP_TTL_MS / 1000 });
    } catch (err) {
      console.error('signup-otp send error:', err);
      return respond({ error: 'حدث خطأ أثناء إرسال رمز التحقق' }, 500);
    }
  }

  // =========================================================================
  //  ACTION 2: VERIFY OTP -> ONLY THEN CREATE VERIFIED USER IN auth.users
  // =========================================================================
  if (action === 'verify') {
    const code = String(body.code ?? '').trim();
    const password = String(body.password ?? '');
    const roleRaw = String(body.role ?? 'customer').trim().toLowerCase();
    const fullName = String(body.full_name ?? '').trim();
    const phone = String(body.phone ?? '').trim();
    const shopName = String(body.shop_name ?? '').trim();

    if (!OTP_RE.test(code)) {
      return respond({ error: 'أدخل رمز التحقق المكوّن من 6 أرقام' }, 400);
    }
    if (password.length < 6) {
      return respond({ error: 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' }, 400);
    }
    if (roleRaw !== 'customer' && roleRaw !== 'shop') {
      return respond({ error: 'نوع الحساب غير صالح' }, 400);
    }
    if (!fullName) {
      return respond({ error: 'يرجى إدخال الاسم الكامل' }, 400);
    }
    if (roleRaw === 'shop' && !shopName) {
      return respond({ error: 'يرجى إدخال اسم المحل' }, 400);
    }

    try {
      const pending = await getPendingOtp(supabaseUrl, serviceKey, email);
      if (!pending) {
        return respond(
          { error: 'رمز التحقق غير صحيح أو منتهي الصلاحية. اطلب رمزاً جديداً.' },
          400,
        );
      }

      const expiresMs = Date.parse(pending.expires_at);
      if (Number.isNaN(expiresMs) || Date.now() > expiresMs) {
        await deletePendingOtp(supabaseUrl, serviceKey, email);
        return respond(
          { error: 'انتهت صلاحية رمز التحقق. اطلب رمزاً جديداً.' },
          400,
        );
      }

      if (pending.attempts >= MAX_VERIFY_ATTEMPTS) {
        await deletePendingOtp(supabaseUrl, serviceKey, email);
        return respond(
          { error: 'تم تجاوز عدد المحاولات المسموح به. اطلب رمزاً جديداً.' },
          429,
        );
      }

      const candidateHash = await hashOtp(pending.salt, code);
      if (!timingSafeEqual(candidateHash, pending.code_hash)) {
        const nextAttempts = pending.attempts + 1;
        if (nextAttempts >= MAX_VERIFY_ATTEMPTS) {
          await deletePendingOtp(supabaseUrl, serviceKey, email);
          return respond(
            { error: 'تم تجاوز عدد المحاولات المسموح به. اطلب رمزاً جديداً.' },
            429,
          );
        }
        await fetch(
          `${supabaseUrl}/rest/v1/pending_email_otps?email=eq.${encodeURIComponent(email)}`,
          {
            method: 'PATCH',
            headers: {
              apikey: serviceKey,
              Authorization: `Bearer ${serviceKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ attempts: nextAttempts }),
          },
        );
        const remaining = MAX_VERIFY_ATTEMPTS - nextAttempts;
        return respond(
          { error: `رمز التحقق غير صحيح (متبقي ${remaining} محاولات).` },
          400,
        );
      }

      // OTP is 100% verified -> consume it immediately (single-use)
      await deletePendingOtp(supabaseUrl, serviceKey, email);

      // Re-check duplicates right before creation to avoid race conditions
      const exists = await checkEmailExists(supabaseUrl, serviceKey, email);
      if (exists) {
        return respond({ error: 'هذا البريد الإلكتروني مسجل مسبقاً' }, 409);
      }
      if (phone) {
        const phoneTaken = await checkPhoneExists(supabaseUrl, serviceKey, phone);
        if (phoneTaken) {
          return respond({ error: 'رقم الهاتف مسجل مسبقاً لحساب آخر' }, 409);
        }
      }

      const userMetadata: Record<string, string> = {
        role: roleRaw,
        full_name: fullName,
        phone,
      };
      if (roleRaw === 'shop') {
        userMetadata.shop_name = shopName;
      }

      // ONLY NOW create the confirmed user in auth.users -> triggers handle_new_user()
      const createRes = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
        method: 'POST',
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email,
          password,
          email_confirm: true,
          user_metadata: userMetadata,
        }),
      });

      const createPayload = await createRes.json().catch(() => ({}));
      if (!createRes.ok) {
        const errMsg = String(
          (createPayload as Record<string, unknown>).msg ??
            (createPayload as Record<string, unknown>).message ??
            '',
        ).toLowerCase();
        console.error('admin/users create failed:', createRes.status, createPayload);
        if (errMsg.includes('already') || errMsg.includes('registered')) {
          return respond({ error: 'هذا البريد الإلكتروني مسجل مسبقاً' }, 409);
        }
        return respond({ error: 'تعذر إنشاء الحساب. حاول مجدداً.' }, 500);
      }

      return respond({
        ok: true,
        user_id: (createPayload as Record<string, unknown>).id ?? null,
      });
    } catch (err) {
      console.error('signup-otp verify error:', err);
      return respond({ error: 'حدث خطأ أثناء التحقق من الرمز' }, 500);
    }
  }

  // =========================================================================
  //  ACTION 3: LOGIN FIRST-INSTALL OTP SEND / RESEND
  //  Verifies password & active status server-side BEFORE sending any OTP.
  // =========================================================================
  if (action === 'login_send' || action === 'login_resend') {
    const password = String(body.password ?? '');
    if (!password) {
      return respond({ error: 'يرجى إدخال كلمة المرور' }, 400);
    }

    try {
      await cleanupExpiredOtps(supabaseUrl, serviceKey);

      const authRes = await fetch(
        `${supabaseUrl}/auth/v1/token?grant_type=password`,
        {
          method: 'POST',
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ email, password }),
        },
      );

      const authPayload = (await authRes.json().catch(() => ({}))) as Record<
        string,
        unknown
      >;
      if (!authRes.ok) {
        const errCode = String(
          authPayload.error_code ??
            authPayload.error_description ??
            authPayload.msg ??
            '',
        ).toLowerCase();
        if (errCode.includes('email_not_confirmed')) {
          return respond({ error: 'يجب تأكيد البريد الإلكتروني أولاً' }, 403);
        }
        return respond({ error: 'البريد أو كلمة المرور غير صحيحة' }, 401);
      }

      const authUser = authPayload.user as Record<string, unknown> | undefined;
      const userId = String(authUser?.id ?? '').trim();
      if (!userId) {
        return respond({ error: 'تعذر التحقق من الحساب' }, 401);
      }

      const profileRes = await fetch(
        `${supabaseUrl}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=is_active&limit=1`,
        {
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
          },
        },
      );
      if (profileRes.ok) {
        const rows = (await profileRes.json().catch(() => [])) as Array<{
          is_active?: boolean;
        }>;
        if (rows.length === 0) {
          return respond({ error: 'لم يتم العثور على ملف المستخدم' }, 403);
        }
        if (rows[0].is_active === false) {
          return respond({ error: 'هذا الحساب موقوف. تواصل مع الإدارة' }, 403);
        }
      }

      const otpKey = `login:${email}`;
      const now = Date.now();
      const existing = await getPendingOtp(supabaseUrl, serviceKey, otpKey);
      let resendCount = 1;
      let windowStartedAt = new Date(now).toISOString();

      if (existing) {
        const lastSentMs = Date.parse(existing.last_sent_at);
        if (!Number.isNaN(lastSentMs)) {
          const elapsed = now - lastSentMs;
          if (elapsed < RESEND_COOLDOWN_MS) {
            const waitSecs = Math.ceil((RESEND_COOLDOWN_MS - elapsed) / 1000);
            return respond(
              {
                error: `يرجى الانتظار ${waitSecs} ثانية قبل طلب رمز تحقق جديد.`,
                retry_after: waitSecs,
              },
              429,
            );
          }
        }

        const windowStartMs = Date.parse(existing.window_started_at);
        if (
          !Number.isNaN(windowStartMs) &&
          now - windowStartMs < HOURLY_WINDOW_MS
        ) {
          if (existing.resend_count >= MAX_SENDS_PER_HOUR) {
            return respond(
              {
                error: 'تم تجاوز الحد الأقصى لطلب رموز التحقق. حاول بعد ساعة.',
              },
              429,
            );
          }
          resendCount = existing.resend_count + 1;
          windowStartedAt = existing.window_started_at;
        }
      }

      const code = generateSixDigitOtp();
      const salt = generateSalt();
      const codeHash = await hashOtp(salt, code);
      const expiresAt = new Date(now + OTP_TTL_MS).toISOString();
      const nowIso = new Date(now).toISOString();

      const upsertRes = await fetch(
        `${supabaseUrl}/rest/v1/pending_email_otps?on_conflict=email`,
        {
          method: 'POST',
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            'Content-Type': 'application/json',
            Prefer: 'resolution=merge-duplicates',
          },
          body: JSON.stringify({
            email: otpKey,
            code_hash: codeHash,
            salt,
            expires_at: expiresAt,
            attempts: 0,
            resend_count: resendCount,
            window_started_at: windowStartedAt,
            last_sent_at: nowIso,
          }),
        },
      );
      if (!upsertRes.ok) {
        const detail = await upsertRes.text().catch(() => '');
        console.error('Upsert login OTP failed:', upsertRes.status, detail);
        return respond({ error: 'تعذر تجهيز رمز التحقق. حاول مجدداً.' }, 500);
      }

      try {
        await sendOtpEmail(email, code, 'login');
      } catch (mailErr) {
        await deletePendingOtp(supabaseUrl, serviceKey, otpKey).catch(() => {});
        const msg = mailErr instanceof Error ? mailErr.message : String(mailErr);
        console.error('sendOtpEmail (login) failed:', msg);
        if (msg === 'EMAIL_PROVIDER_NOT_CONFIGURED') {
          return respond(
            {
              error:
                'خدمة إرسال البريد غير مُعدّة على الخادم بعد (SMTP_USER / SMTP_PASS أو RESEND_API_KEY).',
            },
            503,
          );
        }
        return respond(
          { error: 'تعذر إرسال رسالة رمز التحقق. تحقق من البريد وحاول مجدداً.' },
          502,
        );
      }

      return respond({ ok: true, expires_in_seconds: OTP_TTL_MS / 1000 });
    } catch (err) {
      console.error('signup-otp login_send error:', err);
      return respond({ error: 'حدث خطأ أثناء إرسال رمز التحقق' }, 500);
    }
  }

  // =========================================================================
  //  ACTION 4: LOGIN FIRST-INSTALL OTP VERIFY
  // =========================================================================
  if (action === 'login_verify') {
    const code = String(body.code ?? '').trim();
    if (!OTP_RE.test(code)) {
      return respond({ error: 'أدخل رمز التحقق المكوّن من 6 أرقام' }, 400);
    }

    const otpKey = `login:${email}`;
    try {
      const pending = await getPendingOtp(supabaseUrl, serviceKey, otpKey);
      if (!pending) {
        return respond(
          { error: 'رمز التحقق غير صحيح أو منتهي الصلاحية. اطلب رمزاً جديداً.' },
          400,
        );
      }

      const expiresMs = Date.parse(pending.expires_at);
      if (Number.isNaN(expiresMs) || Date.now() > expiresMs) {
        await deletePendingOtp(supabaseUrl, serviceKey, otpKey);
        return respond(
          { error: 'انتهت صلاحية رمز التحقق. اطلب رمزاً جديداً.' },
          400,
        );
      }

      if (pending.attempts >= MAX_VERIFY_ATTEMPTS) {
        await deletePendingOtp(supabaseUrl, serviceKey, otpKey);
        return respond(
          { error: 'تم تجاوز عدد المحاولات المسموح به. اطلب رمزاً جديداً.' },
          429,
        );
      }

      const candidateHash = await hashOtp(pending.salt, code);
      if (!timingSafeEqual(candidateHash, pending.code_hash)) {
        const nextAttempts = pending.attempts + 1;
        if (nextAttempts >= MAX_VERIFY_ATTEMPTS) {
          await deletePendingOtp(supabaseUrl, serviceKey, otpKey);
          return respond(
            { error: 'تم تجاوز عدد المحاولات المسموح به. اطلب رمزاً جديداً.' },
            429,
          );
        }
        await fetch(
          `${supabaseUrl}/rest/v1/pending_email_otps?email=eq.${encodeURIComponent(otpKey)}`,
          {
            method: 'PATCH',
            headers: {
              apikey: serviceKey,
              Authorization: `Bearer ${serviceKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ attempts: nextAttempts }),
          },
        );
        const remaining = MAX_VERIFY_ATTEMPTS - nextAttempts;
        return respond(
          { error: `رمز التحقق غير صحيح (متبقي ${remaining} محاولات).` },
          400,
        );
      }

      await deletePendingOtp(supabaseUrl, serviceKey, otpKey);
      return respond({ ok: true });
    } catch (err) {
      console.error('signup-otp login_verify error:', err);
      return respond({ error: 'حدث خطأ أثناء التحقق من الرمز' }, 500);
    }
  }

  return respond({ error: 'إجراء غير مدعوم' }, 400);
});
