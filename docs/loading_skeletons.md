# Page-shaped loading

`skeletonizer` renders each page's existing data builder with presentation-only
fixtures. `AsyncValue.skeletonWhen` requires an explicitly typed placeholder;
`AdminAsyncBody` uses the same approach for admin pages. Keep layout changes in
the normal builder so loading and loaded content stay aligned.

- Fixtures never enter providers, repositories, cart state, or persistence.
- Skeletons block pointer/focus interaction and expose one loading accessibility
  label. Reduced-motion settings disable animation.
- Existing data stays visible during refresh. Empty/error/retry branches still
  use real request state.
- `AppNetworkImage` uses the existing image bounds, skips image requests inside
  skeletons, and shows a skeleton until actual image bytes arrive.
- Pagination uses the real `ProductGridCard` dimensions (two columns, 0.58 ratio).
- Actions keep their label dimensions while busy. Camera setup keeps its status
  text and camera-shaped placeholder; it never pretends a stream is connected.

Validation: `flutter test test/loading/page_skeleton_test.dart` exercises actual
customer/admin/shop pages at mobile width, card geometry, disabled placeholder
actions, refresh behavior, and error handling. No browser control is needed.
