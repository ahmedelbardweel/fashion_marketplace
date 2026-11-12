# Local pose model

`pose_landmarker_lite.task` is the version 1 float16 Pose Landmarker Lite asset
published by Google. It is shared by Android, iOS, and the browser worker.

Source: https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task

SHA-256: `59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a`

Model documentation, model card, and upstream notices:
https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker

Runtime dependencies are pinned to MediaPipe Tasks Vision 0.10.21. The browser
loads that version's JS/WASM from jsDelivr; the model is served by this app.
No camera images are sent to the CDN or Google for landmark inference.
