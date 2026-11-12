// Model inference runs in a worker. Only library/model assets use the network.
(() => {
  let worker, sequence = 0, warmed = false;
  const pending = new Map();
  const failure = code => Object.assign(new Error(`[body-analysis:${code}]`), {code});
  const close = (code = 'cancelled') => {
    worker?.terminate();
    worker = undefined;
    warmed = false;
    for (const {reject, timer} of pending.values()) {
      clearTimeout(timer);
      reject(failure(code));
    }
    pending.clear();
  };
  window.fashionBodyClose = () => close();
  window.fashionBodyAnalyze = (bytes) => new Promise((resolve, reject) => {
    if (!worker) {
      // MediaPipe's WASM loader requires classic-worker importScripts support.
      worker = new Worker(new URL('body_analysis_worker.js', document.baseURI));
      worker.onmessage = ({data}) => {
        const request = pending.get(data.id);
        if (!request) return;
        pending.delete(data.id);
        clearTimeout(request.timer);
        if (data.error) request.reject(failure(data.error));
        else {
          warmed = true;
          request.resolve(JSON.stringify(data.poses));
        }
      };
      worker.onerror = () => close('worker_load');
      worker.onmessageerror = () => close('worker_load');
    }
    const id = ++sequence;
    // First use downloads/compiles WASM and loads the model. Give startup its
    // own budget; ordinary analysis does not inherit a one-minute timeout.
    const timer = setTimeout(() => close('timeout'), warmed ? 8000 : 60000);
    pending.set(id, {resolve, reject, timer});
    worker.postMessage({id, bytes,
      model: new URL('assets/assets/models/pose_landmarker_lite.task', document.baseURI).href});
  });
})();
