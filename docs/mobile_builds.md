# GitHub mobile builds

Push to main/master or run Build Android APK and iPhone IPA manually in Actions.
Download outputs from the completed run's Artifacts section:

- fashion-marketplace-android-apk: release APK, using the project's existing debug signing for direct device testing. Store distribution requires a permanent release keystore.
- fashion-marketplace-iphone-unsigned-ipa: unsigned IPA for iOS 16+. Sign using Sideloadly or your own Apple signing process before installation. This artifact cannot be installed directly or uploaded to TestFlight as-is.

The workflow uses Flutter 3.47.5, Java 17 and macOS 26, and resolves the checked-in pubspec.lock without upgrading packages during CI.
`config/mobile.env` contains only the public Supabase URL and anon/publishable client key (the same values distributed with the app). Database access is controlled by Supabase auth and RLS. Never add Decart keys, service-role keys or signing credentials to this file. DECART_API_KEY stays in Supabase Edge Function secrets. The decart-session function must be deployed separately.

iOS builds run on GitHub's macOS runner; they cannot be verified with Xcode on the Windows development machine. Android/iOS build success must be checked in the actual Actions run.
