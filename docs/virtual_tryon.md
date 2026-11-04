# Live virtual try-on

## Layers

- `lib/features/virtual_tryon/domain/tryon_session.dart`: session boundary, garment input and exact requested prompt.
- `lib/features/virtual_tryon/data/`: capture, temporary session configuration and bounded reference-image loading.
- `lib/core/services/decart_realtime_service.dart`: implementation of the session boundary; serialized SDP/ICE, WS, acknowledgments, deadlines, cleanup and server-initiated TURN restart.
- `lib/features/customer/presentation/providers/decart_tryon_provider.dart`: Riverpod controller using the domain interface; coalesces rapid selections and serializes updates.
- `lib/features/customer/presentation/screens/decart_tryon_screen.dart`: full-screen RTC renderer, first-frame confirmation, carousel, retry, lifecycle handling.

Existing product-details navigation already opens the Decart screen.

## Server setup

1. Store `DECART_API_KEY` in **Supabase Edge Function secrets**, never Flutter's bundled `.env`, Dart source, or `--dart-define`.
2. Deploy `supabase/functions/decart-session/index.ts` as `decart-session` with JWT verification enabled. It authenticates users through Supabase Auth and requests a 60-second client token scoped to `lucy-vton-3.6`; a session lasts at most 120 seconds. Retry obtains a fresh token. No server deployment was performed by this change.
3. Optionally provide `DECART_ICE_SERVERS_JSON`, an array of RTC ICE servers with `urls`, `username`, `credential`. Use a TURN credential issuer with short-lived credentials in production. `DECART_RELAY_ONLY=true` requires a working TURN entry. STUN alone cannot traverse every network.
4. Before a public rollout, apply per-user quotas/rate limits at your gateway. The session duration bound is not a per-user spending quota.
5. Product `arFrontImage` (or its model fallback) must be an HTTPS JPEG/PNG/WebP URL accessible by the device, at most 4 MiB. Browser builds also need image-server CORS. The initial implementation targets Android/iOS.

## Capture and performance

The desired capture profile is 1280 x 720 at 30 FPS. Actual capture depends on hardware and negotiation; server output FPS depends on the chosen model/network and is not promised to equal 30.

The try-on screen requests portrait orientation. Mobile browsers request 720 x 1280 with no crop/scale and 1x zoom as ideal constraints; browsers may ignore unsupported constraints. Native capture retains landscape sensor dimensions and uses device rotation, resetting digital zoom to the capturer minimum after opening or switching cameras. The renderer uses `contain` to preserve the whole returned frame, and the garment carousel starts collapsed. Different camera/server aspect ratios can still produce black margins. Full-body visibility depends on the lens and distance; this does not select an ultrawide lens or generate missing body regions.

On Android/iOS, `camera.availableCameras()` discovers cameras and selects front/back direction. On web, WebRTC opens the camera directly once with standard ideal constraints; camera_web discovery itself opens each camera and is skipped. `flutter_webrtc.getUserMedia` owns native capture, encoding and transport. The public Dart APIs in these packages do **not** connect a `CameraController.startImageStream` to an RTC video track. Opening both captures on the same camera can fail. Feeding `CameraImage` specifically requires an Android/iOS native bridge (not included); this implementation deliberately uses native WebRTC capture for a working Dart-only path. No per-frame Dart/JSON/base64 work occurs.

Only product images are downloaded and encoded, using `compute` on mobile. RTCVideoView renders through a native texture in a RepaintBoundary. Rapid taps retain only the latest pending selection; one acknowledged update is allowed at a time because Decart's image acknowledgments do not include request IDs.

## Wire protocol

The service connects to `wss://api.decart.ai/v1/stream` with a short-lived `api_key` and the server-selected model. It exchanges `offer`, `answer`, and `ice-candidate` messages. The domain input contains the garment URL; the data adapter fetches it and sends the documented `set_image` JSON containing `image_data`, the exact prompt, and `enhance_prompt: false`. Raw `garment_url` / `update_garment` messages are not a supported Decart contract. Control uses WebSocket; no speculative DataChannel protocol is created.

The loader disappears only when the peer is connected, the initial garment is acknowledged, and the presentation binding confirms a first remote frame (native renderer callback or browser requestVideoFrameCallback, with HAVE_CURRENT_DATA fallback). An acknowledgment confirms acceptance, not a guarantee about visual fidelity. A local camera preview is never reported as processed video. Missing acknowledgments close the session to prevent late acknowledgments from confirming another product.

## Validation

Run `flutter pub get`, `flutter analyze lib/core/services/decart_realtime_service.dart lib/features/virtual_tryon lib/features/customer/presentation/providers/decart_tryon_provider.dart lib/features/customer/presentation/screens/decart_tryon_screen.dart`, and `flutter test test/virtual_tryon`.

On physical Android and iOS devices verify camera denial, first-frame timeout, foreground/background, navigation away during permission/token fetch, fast garment switching, rejected images, offline/retry, and a restricted network with TURN. Live video quality and server connectivity require a deployed token function, an active Decart account and physical-camera testing.

Protocol sources checked during implementation:
- https://docs.platform.decart.ai/integrations/signaling-proxy-ws
- https://docs.platform.decart.ai/getting-started/client-tokens
- https://docs.platform.decart.ai/models/realtime/virtual-try-on
- https://github.com/flutter-webrtc/flutter-webrtc/issues/1939

## Browser startup troubleshooting

The UI now distinguishes camera permission denial, missing devices, busy/unreadable cameras, unsupported constraints, timeouts, session HTTP failures, peer setup, signaling and reference-image loading. Raw errors are classified locally and never displayed, so session tokens and signed image URLs are not exposed. Supabase HTTP 404 reports a missing session function; 401/403 requests a fresh login; 502/503 identifies the server-side session configuration or availability problem.

After changing Dart code in an existing Flutter web development session, perform a hot restart or stop and run the app again. Refreshing a page served by an older build does not deploy the new code. Chrome's iPhone device emulation only changes the viewport/device behavior; it still uses the computer's webcam. A successful compile or mock test does not verify camera permissions, CORS, deployment, account credits, or a live Decart stream.

## Web first-frame handling

The installed flutter_webrtc 0.12.x web renderer declares `onFirstFrameRendered` without invoking it. `RemoteVideoBinding` uses the browser video element's first presented-frame callback, then stops observing. Older browsers fall back to an actual current frame with positive dimensions. Native platforms retain their renderer callback. Detach/retry/dispose cancel pending frame callbacks; generation checks ignore stale callbacks. The connection still requires the server garment acknowledgment and connected peer before the initial overlay disappears.

Regression: `flutter test --no-pub --platform chrome test/virtual_tryon/remote_video_web_test.dart` uses a synthetic canvas stream, not a camera or Decart session.
