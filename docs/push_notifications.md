# Push Notifications Setup (Android & iOS)

The app supports:
- **Runtime permission requests** on Android 13+ (`POST_NOTIFICATIONS`) and iOS (`UNUserNotificationCenter`), prompted automatically after login and toggleable in Profile/Settings.
- **Foreground instant banners** via Supabase Realtime (`public.notifications` `INSERT`).
- **Background/killed-app push**:
  - **Android & iOS via FCM**: Add `FIREBASE_*` keys to `config/mobile.env` / `.env` and set `FIREBASE_SERVICE_ACCOUNT_JSON` secret in Supabase Edge Functions (plus APNs `.p8` in Firebase Console for iOS).
  - **Direct iOS APNs without Firebase**: Set `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID`, and `APNS_BUNDLE_ID` in Supabase Edge Functions.
  - **Android fallback sync without Firebase**: `workmanager` periodically checks for missed notifications when FCM keys are not configured.
- **Admin & Shop sending**:
  - Admin (`AdminNotificationsScreen`) -> `admin_send_notification` -> `send-push-notification`
  - Approved Shop Owner (`ShopNotificationsScreen`) -> `shop_send_notification` (`shop_customers` or `all_customers`) -> `send-push-notification`
  - Order status updates (`shop_update_order_status`) -> `send-push-notification`

## Deploy Backend
1. Run `supabase/migrations/018_push_notifications.sql` in Supabase SQL Editor.
2. Deploy `supabase/functions/send-push-notification`:
   ```bash
   supabase functions deploy send-push-notification
   ```
3. Configure `FIREBASE_SERVICE_ACCOUNT_JSON` (for FCM Android+iOS) and/or `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID` (for direct iOS APNs) as Edge Function Secrets.
