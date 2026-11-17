# Push Notifications Setup (Android & iOS)

The app supports:
- **Runtime permission requests** on Android 13+ (`POST_NOTIFICATIONS`) and iOS (`UNUserNotificationCenter`), automatically prompted once after sign-in and controllable at any time from Profile/Settings.
- **Admin notifications** (`AdminNotificationsScreen` -> `admin_send_notification` RPC -> `send-push-notification` Edge Function) to `all`, `customer`, or `shop`.
- **Shop owner notifications** (`ShopNotificationsScreen` -> `shop_send_notification` RPC -> `send-push-notification` Edge Function) to `shop_customers` (customers who previously ordered from the shop) or `all_customers`.
- **Automatic order status notifications** (`shop_update_order_status` RPC -> `send-push-notification` Edge Function).
- **Foreground Supabase Realtime fallback** so active sessions receive instant local notification banners and unread badge updates even before Firebase credentials are configured.

## 1. Database Migration & Edge Function
1. Apply `supabase/migrations/018_push_notifications.sql` in Supabase SQL Editor (or `supabase db push`).
2. Deploy the Edge Function:
   ```bash
   supabase functions deploy send-push-notification
   ```
3. Set the Firebase Service Account JSON secret for FCM HTTP v1 delivery:
   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"project_id":"...","client_email":"...","private_key":"..."}'
   ```

## 2. Firebase Client Keys (Android & iOS)
Add the following public Firebase app keys to `config/mobile.env` (and `.env` locally), or drop `google-services.json` / `GoogleService-Info.plist` into `android/app/` and `ios/Runner/`:

```env
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_MESSAGING_SENDER_ID=756058625665
FIREBASE_ANDROID_API_KEY=your-android-api-key
FIREBASE_ANDROID_APP_ID=1:756058625665:android:...
FIREBASE_IOS_API_KEY=your-ios-api-key
FIREBASE_IOS_APP_ID=1:756058625665:ios:...
FIREBASE_IOS_BUNDLE_ID=com.example.fashionMarketplace
```

## 3. iOS APNs Setup (Required for Background Push on iPhone)
1. In Apple Developer Portal, create an **APNs Auth Key (`.p8`)**.
2. Upload the `.p8` key, Key ID, and Team ID in **Firebase Console → Project Settings → Cloud Messaging → Apple app configuration**.
3. When signing the iOS app in Xcode with your Apple Developer Team, enable the **Push Notifications** capability (and **Background Modes → Remote notifications**, already configured in `ios/Runner/Info.plist`).
