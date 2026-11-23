import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../network/tryon_bandwidth_guard.dart';
import '../utils/app_image_compressor.dart';
import 'network_monitor_service.dart';

/// Persistent disk cache and background pre-downloader for all network images
/// (banners, shops, products, variants, AR overlays, cart & order thumbnails).
///
/// Ensures all images remain visible offline even after app restarts.
class OfflineImageCacheService {
  OfflineImageCacheService._();

  static final OfflineImageCacheService instance =
      OfflineImageCacheService._();

  static const String _cacheSubDir = 'shopy_offline_images_v1';
  static const int _maxConcurrentPrefetches = 3;

  Directory? _cacheDir;
  bool _initialized = false;
  Future<void>? _initFuture;

  /// Fast O(1) in-memory index of hash keys known to exist on disk.
  final Set<String> _cachedKeys = <String>{};

  /// Deduplicates concurrent downloads for the same URL.
  final Map<String, Future<File?>> _inFlight = <String, Future<File?>>{};

  /// Background prefetch queue.
  final Queue<String> _prefetchQueue = Queue<String>();
  final Set<String> _queuedUrls = <String>{};
  int _activePrefetchWorkers = 0;

  bool get isReady => _initialized && _cacheDir != null;

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = _doInitialize();
    return _initFuture;
  }

  Future<void> _doInitialize() async {
    try {
      final baseDir = await getApplicationSupportDirectory();
      final dir = Directory(p.join(baseDir.path, _cacheSubDir));
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;

      // Index existing cached files into memory for 0ms synchronous lookup
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (!name.endsWith('.tmp')) {
            _cachedKeys.add(name);
          }
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[OfflineImageCacheService] Initialization warning: $e');
    } finally {
      _initFuture = null;
    }
  }

  String _keyForUrl(String url) {
    final trimmed = url.trim();
    final digest = sha256.convert(utf8.encode(trimmed)).toString();
    return '$digest.img';
  }

  /// Synchronous O(1) lookup returning the cached [File] if already on disk.
  File? getCachedFileSync(String url) {
    if (kIsWeb || !_initialized || _cacheDir == null) return null;
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;

    final key = _keyForUrl(cleanUrl);
    if (!_cachedKeys.contains(key)) return null;

    final file = File(p.join(_cacheDir!.path, key));
    if (file.existsSync()) {
      return file;
    }
    _cachedKeys.remove(key);
    return null;
  }

  /// Returns the cached [File] if present on disk, or downloads and persists
  /// it from the network when online.
  Future<File?> getOrDownloadFile(String url) async {
    if (kIsWeb) return null;
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) return null;

    if (!_initialized) {
      await initialize();
    }
    if (_cacheDir == null) return null;

    final existing = getCachedFileSync(cleanUrl);
    if (existing != null) return existing;

    final key = _keyForUrl(cleanUrl);
    final inflight = _inFlight[key];
    if (inflight != null) return inflight;

    final future = _downloadAndSave(cleanUrl, key);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<File?> _downloadAndSave(String url, String key) async {
    if (_cacheDir == null) return null;

    final targetFile = File(p.join(_cacheDir!.path, key));
    if (targetFile.existsSync()) {
      final len = await targetFile.length();
      if (len > 0) {
        _cachedKeys.add(key);
        return targetFile;
      }
    }

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final contentType = response.headers['content-type'];
        var bytesToStore = response.bodyBytes;
        if (AppImageCompressor.isCompressibleImage(
          fileName: uri.path,
          contentType: contentType,
        )) {
          final preferPng =
              (contentType?.toLowerCase().contains('png') ?? false) ||
              uri.path.toLowerCase().endsWith('.png');
          bytesToStore = await AppImageCompressor.compressBytes(
            bytesToStore,
            preset: ImageCompressPreset.diskCache,
            preferPng: preferPng,
          );
        }
        final tmpFile = File(p.join(_cacheDir!.path, '$key.tmp'));
        await tmpFile.writeAsBytes(bytesToStore, flush: true);
        final saved = await tmpFile.rename(targetFile.path);
        _cachedKeys.add(key);
        return saved;
      }
    } catch (_) {}

    return null;
  }

  /// Deletes any cached image files on disk whose URL is no longer in [keepUrls]
  /// and removes stale URLs from the pending prefetch queue.
  Future<int> pruneUnreferencedUrls(Iterable<String?> keepUrls) async {
    if (kIsWeb) return 0;
    if (!_initialized) {
      await initialize();
    }
    final dir = _cacheDir;
    if (dir == null || !dir.existsSync()) return 0;

    final keepKeys = <String>{};
    final keepCleanUrls = <String>{};
    for (final raw in keepUrls) {
      final clean = raw?.trim() ?? '';
      if (clean.isEmpty || !clean.startsWith('http')) continue;
      keepCleanUrls.add(clean);
      keepKeys.add(_keyForUrl(clean));
    }

    // Drop queued URLs that are no longer needed
    if (_prefetchQueue.isNotEmpty) {
      final filtered = _prefetchQueue.where(keepCleanUrls.contains).toList();
      _prefetchQueue
        ..clear()
        ..addAll(filtered);
      _queuedUrls.removeWhere((u) => !keepCleanUrls.contains(u));
    }

    var removed = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.endsWith('.tmp')) continue;
        if (!keepKeys.contains(name)) {
          try {
            await entity.delete();
            _cachedKeys.remove(name);
            removed++;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[OfflineImageCacheService] Prune warning: $e');
    }
    return removed;
  }

  /// Enqueues image URLs to be silently downloaded to disk in the background
  /// without blocking the UI or saturating network bandwidth.
  void prefetchUrlsSilently(Iterable<String?> urls) {
    if (kIsWeb) return;
    for (final raw in urls) {
      final clean = raw?.trim() ?? '';
      if (clean.isEmpty || !clean.startsWith('http')) continue;
      final key = _keyForUrl(clean);
      if (_cachedKeys.contains(key) || _queuedUrls.contains(clean)) continue;
      _queuedUrls.add(clean);
      _prefetchQueue.add(clean);
    }
    _pumpPrefetchQueue();
  }

  /// Resumes background image prefetching after a Try-On focus session ends.
  void resumePrefetch() {
    if (kIsWeb || TryonNetworkFocus.instance.isActive) return;
    _pumpPrefetchQueue();
  }

  void _pumpPrefetchQueue() {
    if (kIsWeb || TryonNetworkFocus.instance.isActive) return;
    while (_activePrefetchWorkers < _maxConcurrentPrefetches &&
        _prefetchQueue.isNotEmpty &&
        !TryonNetworkFocus.instance.isActive) {
      final nextUrl = _prefetchQueue.removeFirst();
      _activePrefetchWorkers++;
      unawaited(_runPrefetchWorker(nextUrl));
    }
  }

  Future<void> _runPrefetchWorker(String url) async {
    try {
      if (TryonNetworkFocus.instance.isActive) {
        // Re-queue so it downloads cleanly once Try-On ends.
        _prefetchQueue.addFirst(url);
        return;
      }
      if (!NetworkMonitorService.instance.isOnline) {
        _queuedUrls.remove(url);
        return;
      }
      await getOrDownloadFile(url);
    } catch (_) {
    } finally {
      if (!TryonNetworkFocus.instance.isActive) {
        _queuedUrls.remove(url);
      }
      _activePrefetchWorkers--;
      if (_prefetchQueue.isNotEmpty &&
          !TryonNetworkFocus.instance.isActive &&
          NetworkMonitorService.instance.isOnline) {
        // Small yield between background image downloads to keep UI silky smooth
        Future<void>.delayed(
          const Duration(milliseconds: 20),
          _pumpPrefetchQueue,
        );
      }
    }
  }
}
