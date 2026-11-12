// Real Chromium + actual MediaPipe/model smoke test, no camera or private images.
// Run: node test/virtual_tryon/browser_body_analysis_smoke.mjs
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile, mkdir, mkdtemp } from 'node:fs/promises';
import { resolve, join, extname, sep } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { once } from 'node:events';

const root = resolve(import.meta.dirname, '../..');
const build = join(root, 'build');
await mkdir(build, {recursive: true});
// The adapter is pure Dart: compile it directly to avoid bringing up Flutter's
// entire web renderer just to test JS promise conversion.
const probe = join(build, 'body_analyzer_interop_probe.js');
const compiled = spawnSync(process.env.DART_EXECUTABLE ?? 'C:/flutter/bin/cache/dart-sdk/bin/dart.exe',
  ['compile', 'js', '-O1', '-o', probe, join(root, 'test/virtual_tryon/fixtures/body_analyzer_interop_probe.dart')],
  {cwd: root, windowsHide: true, encoding: 'utf8', timeout: 60000});
assert.equal(compiled.status, 0, compiled.stderr || compiled.error?.message || 'Dart probe compile failed');
const profile = await mkdtemp(join(build, 'body-analysis-chrome-'));
let blockModel = false;
const server = createServer(async (request, response) => {
  const pathname = new URL(request.url, 'http://localhost').pathname;
  response.setHeader('Cache-Control', 'no-store');
  if (blockModel && pathname.endsWith('.task')) { response.writeHead(404).end(); return; }
  if (pathname === '/preview/index.html') {
    response.setHeader('Content-Type', 'text/html');
    response.end('<!doctype html><base href="/preview/"><script src="body_analysis.js"></script><body>Body analysis smoke test</body>');
    return;
  }
  const local = pathname === '/preview/body_analyzer_interop_probe.js' ? probe : pathname.startsWith('/preview/assets/assets/')
    ? resolve(root, pathname.replace('/preview/assets/', ''))
    : resolve(root, 'web', pathname.replace('/preview/', ''));
  if (!local.startsWith(root + sep)) { response.writeHead(403).end(); return; }
  try {
    const content = await readFile(local);
    response.setHeader('Content-Type', ({'.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm'})[extname(local)] ?? 'application/octet-stream');
    response.end(content);
  } catch (_) { response.writeHead(404).end(); }
});
server.listen(0, '127.0.0.1');
await once(server, 'listening');
const url = `http://127.0.0.1:${server.address().port}/preview/index.html`;
const chrome = spawn(process.env.CHROME_EXECUTABLE ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe', [
  '--headless=new', '--no-first-run', '--no-default-browser-check',
  '--enable-unsafe-swiftshader', '--remote-debugging-port=0',
  `--user-data-dir=${profile}`, 'about:blank',
], {windowsHide: true, stdio: 'ignore'});
let socket;
try {
  let port;
  for (let i = 0; i < 100; i++) {
    try { port = (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; break; }
    catch (_) { await new Promise(r => setTimeout(r, 100)); }
  }
  assert.ok(port, 'Chromium did not start');
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  socket = new WebSocket(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
  await once(socket, 'open');
  let sequence = 0;
  const requests = new Map();
  const events = new Map();
  socket.addEventListener('message', ({data}) => {
    const message = JSON.parse(data);
    if (message.id) {
      const request = requests.get(message.id);
      if (!request) return;
      requests.delete(message.id);
      clearTimeout(request.timer);
      if (message.error) request.reject(new Error(message.error.message));
      else request.resolve(message.result);
    } else events.get(message.method)?.(message.params);
  });
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => { requests.delete(id); reject(new Error(`Timeout: ${method}`)); }, 90000);
    requests.set(id, {resolve, reject, timer});
    socket.send(JSON.stringify({id, method, params}));
  });
  await send('Page.enable');
  await send('Runtime.enable');
  events.set('Runtime.consoleAPICalled', event => {
    if (event.type === 'error') console.error('Browser:', event.args.map(a => a.value ?? a.description).join(' '));
  });
  const loaded = new Promise(resolve => events.set('Page.loadEventFired', resolve));
  await send('Page.navigate', {url});
  await loaded;
  const loopback = await send('Runtime.evaluate', {expression: `(async () => {
    const canvas = document.createElement('canvas'); canvas.width = 256; canvas.height = 256;
    const context = canvas.getContext('2d');
    const source = canvas.captureStream(15);
    const sender = new RTCPeerConnection({iceServers: []});
    const receiver = new RTCPeerConnection({iceServers: []});
    const video = document.createElement('video'); video.muted = true; video.autoplay = true;
    video.setAttribute('playsinline', ''); document.body.append(video);
    const draw = setInterval(() => { context.fillStyle = '#2060c0'; context.fillRect(0,0,256,256); }, 60);
    const bounded = promise => Promise.race([promise, new Promise((_, reject) => setTimeout(() => reject(new Error('loopback timeout')), 8000))]);
    sender.onicecandidate = event => { if (event.candidate) receiver.addIceCandidate(event.candidate).catch(() => {}); };
    receiver.onicecandidate = event => { if (event.candidate) sender.addIceCandidate(event.candidate).catch(() => {}); };
    let announcedBeforeFrame = false;
    const remote = new Promise(resolve => { receiver.ontrack = event => {
      announcedBeforeFrame = video.readyState < 2;
      video.srcObject = new MediaStream([event.track]); resolve(event.track);
    }; });
    try {
      sender.addTrack(source.getVideoTracks()[0], source);
      await sender.setLocalDescription(await sender.createOffer());
      await receiver.setRemoteDescription(sender.localDescription);
      await receiver.setLocalDescription(await receiver.createAnswer());
      await sender.setRemoteDescription(receiver.localDescription);
      const track = await bounded(remote);
      const firstFrame = new Promise(resolve => video.requestVideoFrameCallback(resolve));
      await bounded(video.play()); await bounded(firstFrame);
      let snapshot;
      try {
        const bitmap = await bounded(new ImageCapture(track).grabFrame());
        snapshot = {width: bitmap.width, height: bitmap.height}; bitmap.close();
      } catch (error) { snapshot = {error: String(error)}; }
      return {announcedBeforeFrame, snapshot};
    } finally {
      clearInterval(draw); source.getTracks().forEach(track => track.stop());
      sender.close(); receiver.close(); video.srcObject = null; video.remove();
    }
  })()`, awaitPromise: true, returnByValue: true});
  console.log('WebRTC:', JSON.stringify(loopback.result.value));
  assert.equal(loopback.exceptionDetails, undefined);
  assert.deepEqual(loopback.result.value, {announcedBeforeFrame: true, snapshot: {width: 256, height: 256}});
  const evaluated = await send('Runtime.evaluate', {
    expression: `(async () => {
      const canvas = document.createElement('canvas'); canvas.width = 256; canvas.height = 256;
      const context = canvas.getContext('2d'); context.fillStyle = '#888'; context.fillRect(0,0,256,256);
      const blob = await new Promise(resolve => canvas.toBlob(resolve));
      const bytes = new Uint8Array(await blob.arrayBuffer());
      window.__bodyTestBytes = bytes;
      try {
        const first = JSON.parse(await window.fashionBodyAnalyze(bytes));
        const second = JSON.parse(await window.fashionBodyAnalyze(bytes));
        window.fashionBodyClose();
        const afterRetry = JSON.parse(await window.fashionBodyAnalyze(bytes));
        window.fashionBodyClose();
        return {first, second, afterRetry};
      } catch (error) { return {error: String(error), code: error.code}; }
    })()`, awaitPromise: true, returnByValue: true,
  });
  assert.equal(evaluated.exceptionDetails, undefined);
  const result = evaluated.result.value;
  console.log(JSON.stringify(result));
  assert.equal(result.error, undefined, 'Real browser inference must load successfully');
  assert.deepEqual(result, {first: [], second: [], afterRetry: []}, 'Blank frames have no people, including after retry');
  blockModel = true;
  const missing = await send('Runtime.evaluate', {expression: `(async () => {
    try { await fashionBodyAnalyze(window.__bodyTestBytes); return 'unexpected success'; }
    catch (error) { return error.code; }
  })()`, awaitPromise: true, returnByValue: true});
  assert.equal(missing.result.value, 'model_load', 'Missing model must be distinguishable from camera failure');
  blockModel = false;
  const recovered = await send('Runtime.evaluate', {expression: `(async () => {
    const afterMissing = JSON.parse(await fashionBodyAnalyze(window.__bodyTestBytes));
    const pending = fashionBodyAnalyze(window.__bodyTestBytes).catch(error => error.code);
    fashionBodyClose();
    const cancelled = await pending;
    const poses = JSON.parse(await fashionBodyAnalyze(window.__bodyTestBytes));
    let invalid;
    try { await fashionBodyAnalyze(new Uint8Array([1,2,3])); }
    catch (error) { invalid = error.code; }
    fashionBodyClose();
    return {afterMissing, cancelled, poses, invalid};
  })()`, awaitPromise: true, returnByValue: true});
  assert.deepEqual(recovered.result.value, {afterMissing: [], cancelled: 'cancelled', poses: [], invalid: 'frame_decode'});
  const interop = await send('Runtime.evaluate', {expression: `new Promise(resolve => {
    window.bodyInteropReport = json => resolve(JSON.parse(json));
    const script = document.createElement('script'); script.src = 'body_analyzer_interop_probe.js';
    script.onerror = () => resolve({failure: 'Dart probe did not load'});
    document.body.append(script);
  })`, awaitPromise: true, returnByValue: true});
  assert.deepEqual(interop.result.value, {empty: true, errorCode: 'frame_decode'}, 'Actual Dart adapter preserves successful results and JS error codes');
  console.log('PASS: real inference, repeated frames, retry, missing model, cancellation, invalid image, recovery, Dart/JS interop');
} finally {
  socket?.close();
  chrome.kill();
  server.closeAllConnections();
  server.close();
}
