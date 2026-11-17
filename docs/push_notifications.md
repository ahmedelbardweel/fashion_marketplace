# Notifications Setup (Pure Supabase — No Firebase)

This project uses a **100% Supabase-powered** notification system without Firebase:

1. **Permissions & Local System Banners (`flutter_local_notifications`)**
   - Requests OS notification permissions on Android 13+ (`POST_NOTIFICATIONS`) and iOS (`UNUserNotificationCenter`) after login and from Profile/Settings.
   - Displays native OS banners with sound when notifications arrive.
2. **Instant Foreground Alerts (Supabase Realtime)**
   - Subscribes to `public.notifications` `INSERT` events so active sessions on Android & iOS show banners and update unread badges immediately.
3. **Android Background Sync (`workmanager`)**
   - Periodically polls Supabase in the background (~every 15 minutes when online) and raises native Android OS notifications for any new items, plus checks for missed notifications on app resume.
4. **Direct iOS APNs Delivery from Supabase (Optional for Closed/Killed iPhone)**
   - `ios/Runner/AppDelegate.swift` exposes the native APNs token over `fashion/apns` and syncs it to `public.device_push_tokens` via `register_push_token`.
   - `supabase/functions/send-push-notification/index.ts` sends push notifications directly to Apple APNs HTTP/2 without Firebase.

## Setup Steps

1. Run `supabase/migrations/018_push_notifications.sql` in Supabase SQL Editor.
2. *(Optional — needed only for iPhone background/killed push)* Deploy the Edge Function and configure Apple APNs secrets:
   ```bash
   supabase functions deploy send-push-notification
   supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"
   supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"
   supabase secrets set APNS_BUNDLE_ID="com.example.fashionMarketplace"
   supabase secrets set APNS_KEY_P8="-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----"
   # Set APNS_USE_SANDBOX="true" for Xcode debug builds, or "false" for TestFlight/App Store
   supabase secrets set APNS_USE_SANDBOX="false"
   ```
3. Sign the iOS app in Xcode with a paid Apple Developer Team that has the **Push Notifications** capability enabled (`Background Modes -> Remote notifications` is already configured in `ios/Runner/Info.plist`).
