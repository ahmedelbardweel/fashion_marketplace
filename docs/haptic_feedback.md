# Native haptic feedback

`AppHaptics` uses Flutter's built-in platform haptics on installed iOS and Android apps. Web and desktop are no-ops. Device support and system haptic settings determine the physical feedback.

- Button and navigation activation: light impact.
- Chips, dropdowns, switches and refresh gestures: selection feedback.
- Shared success/info snackbars: medium impact.
- Shared error snackbars: heavy impact.

Callbacks retain nullability so disabled/loading controls stay disabled. Haptics are fire-and-forget, catch unsupported-platform errors, and never delay the action. A short throttle prevents overlapping controls from sending duplicate pulses; result feedback has a separate throttle so a completed action can still be acknowledged.

Shared AppButton/AppIconButton/AppCard wrap their underlying callbacks once. Native Material buttons, clickable cards, custom gesture controls, and selection controls elsewhere use `AppHaptics.action`, `AppHaptics.change` or `AppHaptics.refresh`. New direct controls should follow this convention. Plain text input and scrolling don't emit continuous haptics.

Test: `flutter test test/core/app_haptics_test.dart`. Tests intercept the platform channel for Android/iOS and verify disabled controls, throttling, selection/result patterns and unavailable native feedback. Physical haptic strength must be checked on real phones.
