# Fashion Marketplace

تطبيق واحد بثلاث واجهات (Admin / Shop / Customer) مع Supabase Auth وRBAC.

## المرحلة 1 — Auth وRBAC

- Splash
- Login
- Register (مستخدم / محل)
- جلسات محفوظة + Logout
- حماية المسارات حسب الدور

## التصميم

- ألوان: أبيض وأسود فقط
- نصف القطر الافتراضي: `2` من `lib/core/theme/app_radii.dart`
- Bottom sheet من الأعلى: `20` من نفس الملف
- غيّر القيمة في `AppRadii` لتتحدث في كل التطبيق

## الإعداد

1. انسخ `.env.example` إلى `.env`
2. ضع `SUPABASE_URL` و `SUPABASE_ANON_KEY`
3. نفّذ SQL: `supabase/migrations/001_auth_profiles.sql` من SQL Editor في Supabase
4. إنشاء أدمن يدوياً:
   - أنشئ مستخدماً من Authentication
   - حدّث دوره في `profiles` إلى `admin`

```sql
update public.profiles
set role = 'admin'
where email = 'admin@example.com';
```

5. شغّل التطبيق:

```bash
flutter pub get
flutter run
```

ملاحظة: فعّل Developer Mode على Windows إن ظهرت رسالة symlink.


## AR Virtual Try-On (تجربة الملابس الافتراضية)
- كشف وتتبع حركة الجسم والكتاف لايف بواسطة Google ML Kit Pose Detection.
- دعم القياس التلقائي وحساب زوايا الميلان ثلاثية الأبعاد.
- التجهيز لمحرك 3D Virtual Try-On عبر Unity AR Foundation و DeepAR.

## GitHub Actions CI/CD (تحميل نسخ التطبيق)
- بناء تلقائي لنسخة الأندرويد بصيغة APK (app-release.apk).
- بناء تلقائي لنسخة الآيفون بصيغة IPA (fashion_marketplace.ipa).
- يمكنك تحميل النسخ مباشرة من تبويب Actions في مستودع GitHub.
