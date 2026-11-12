// This MUST be a classic worker: MediaPipe 0.10.21's WASM loader uses
// importScripts(). Dynamic import loads the ESM API without making the worker
// itself a module worker (which would prohibit importScripts).
let detector;
self.onmessage = async ({data}) => {
  let bitmap;
  let stage = 'runtime_load';
  try {
    if (typeof OffscreenCanvas !== 'function' || typeof createImageBitmap !== 'function') {
      self.postMessage({id: data.id, error: 'unsupported'});
      return;
    }
    if (!detector) {
      const {FilesetResolver, PoseLandmarker} = await import(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.21/vision_bundle.mjs');
      const vision = await FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.21/wasm');
      stage = 'model_load';
      detector = await PoseLandmarker.createFromOptions(vision, {
        baseOptions: {modelAssetPath: data.model, delegate: 'CPU'},
        runningMode: 'IMAGE', numPoses: 3,
        minPoseDetectionConfidence: 0.5, minPosePresenceConfidence: 0.5,
      });
    }
    stage = 'frame_decode';
    bitmap = await createImageBitmap(new Blob([data.bytes], {type: 'image/png'}));
    const scale = Math.min(1, 640 / Math.max(bitmap.width, bitmap.height));
    const canvas = new OffscreenCanvas(Math.round(bitmap.width * scale), Math.round(bitmap.height * scale));
    canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    stage = 'inference';
    const result = detector.detect(canvas);
    const poses = result.landmarks.map(pose => pose.map(p => ({
      x: p.x, y: p.y, z: p.z,
      visibility: Math.min(p.visibility ?? 0, p.presence ?? 1),
    })));
    self.postMessage({id: data.id, poses});
  } catch (_) {
    // Send bounded diagnostic codes, never image data or raw engine errors.
    self.postMessage({id: data.id, error: stage});
  } finally { bitmap?.close(); }
};
