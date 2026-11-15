import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../domain/capture_quality.dart';
import '../domain/tryon_session.dart';
import 'body_analyzer.dart';
import 'body_analysis_failure.dart';
import 'capture_read_failure.dart';
import 'frame_quality.dart';

abstract interface class CaptureGuard {
  Future<void> validate(
    MediaStream stream,
    GarmentSelection garment,
    void Function(String) onUnsafe,
  );
  void cancel();
}

/// One camera owner, one bounded analysis at a time. Revalidate every session.
class CaptureGuardController extends ChangeNotifier implements CaptureGuard {
  CaptureGuardController({
    Future<List<List<BodyPoint>>> Function(Uint8List)? analyzeFrame,
    Future<CaptureObservation> Function(Uint8List, List<List<BodyPoint>>)?
    inspectFrame,
    Duration Function()? elapsed,
  }) : _analyzeFrame = analyzeFrame,
       _inspectFrame = inspectFrame ?? observeFrame,
       _elapsed = elapsed;

  final Future<List<List<BodyPoint>>> Function(Uint8List)? _analyzeFrame;
  final Future<CaptureObservation> Function(Uint8List, List<List<BodyPoint>>)
  _inspectFrame;
  final Duration Function()? _elapsed;
  final _analyzer = BodyAnalyzer();
  final _gate = CaptureQualityGate();
  final _clock = Stopwatch()..start();
  Timer? _timer;
  Completer<void>? _permission;
  MediaStream? stream;
  MediaStream? _outputStream;
  MediaStream? get outputStream => _outputStream;
  set outputStream(MediaStream? value) {
    if (identical(value, _outputStream)) return;
    _outputStream = value;
    _invalidateOutput();
    if (!_disposed) notifyListeners();
  }

  bool outputAligned = false;
  List<BodyPoint> overlayPoints = const [];
  List<BodyPoint> outputPoints = const [];
  GarmentSelection? garment;
  CaptureObservation? observation;
  CaptureAssessment assessment = const CaptureAssessment();
  String? error;
  bool approved = false;
  bool analyzing = false;
  bool _busy = false, _disposed = false;
  int _generation = 0;
  Duration? _lastFrame;
  Duration? _lastOutputFrame;
  Duration? _outputMismatchSince;
  void Function(String)? _onUnsafe;
  Duration get _now => _elapsed?.call() ?? _clock.elapsed;

  bool get fresh =>
      _lastFrame != null &&
      _now - _lastFrame! < const Duration(milliseconds: 1800);
  bool get canShowOverlay =>
      approved &&
      assessment.ready &&
      fresh &&
      outputAligned &&
      _outputStream != null &&
      _lastOutputFrame != null &&
      _now - _lastOutputFrame! < const Duration(milliseconds: 900);
  bool get canApprove => assessment.ready && fresh && error == null;

  void _invalidateOutput() {
    outputAligned = false;
    _lastOutputFrame = null;
    overlayPoints = const [];
    outputPoints = const [];
  }

  @override
  Future<void> validate(
    MediaStream source,
    GarmentSelection selected,
    void Function(String) onUnsafe,
  ) {
    cancel();
    stream = source;
    garment = selected;
    error = null;
    observation = null;
    assessment = const CaptureAssessment();
    _invalidateOutput();
    _gate.reset();
    _lastFrame = null;
    _outputMismatchSince = null;
    _onUnsafe = onUnsafe;
    analyzing = true;
    final permission = _permission = Completer<void>();
    final generation = _generation;
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (outputAligned && !canShowOverlay) {
        _invalidateOutput();
        notifyListeners();
      }
      // Expired/missing observations never leave a validated overlay visible.
      if (approved && !fresh) {
        _unsafe('توقف فحص الكاميرا. أعد الفحص قبل المتابعة.');
      } else if (!_busy) {
        unawaited(_sample(generation));
      }
    });
    notifyListeners();
    return permission.future;
  }

  void _completeApproval() {
    if (!canApprove || _permission == null) return;
    approved = true;
    _permission!.complete();
    _permission = null;
    notifyListeners();
  }

  Future<void> _sample(int generation) async {
    final track = stream?.getVideoTracks().firstOrNull;
    final selected = garment;
    if (track == null || selected == null) return;
    _busy = true;
    var readStage = CaptureReadStage.cameraFrame;
    try {
      final bytes = (await track.captureFrame().timeout(
        const Duration(seconds: 3),
      )).asUint8List();
      final capturedAt = _now;
      if (_disposed || generation != _generation) return;
      readStage = CaptureReadStage.cameraAnalysis;
      final poses = await (_analyzeFrame ?? _analyzer.analyze)(
        bytes,
      ).timeout(const Duration(seconds: 65));
      final frame = await _inspectFrame(bytes, poses);
      if (_disposed || generation != _generation) return;
      if (_now - capturedAt > const Duration(milliseconds: 1800)) {
        _gate.reset();
        assessment = const CaptureAssessment(issue: CaptureIssue.unavailable);
        if (approved) _unsafe('الفحص بطيء على هذا الجهاز. أعد المحاولة.');
        return;
      }
      observation = frame;
      _lastFrame = capturedAt;
      assessment = _gate.evaluate(frame, selected, capturedAt);
      if (approved && !assessment.ready) {
        _invalidateOutput();
        if (assessment.issue != CaptureIssue.multiplePeople &&
            assessment.issue != CaptureIssue.unavailable) {
          _outputMismatchSince = null;
          return; // Recover framing/light/movement without restarting the stream.
        }
        _unsafe(assessment.issue?.message ?? 'أعد تثبيت وضعيتك.');
        return;
      }
      if (!approved) _completeApproval();
      final sampledOutput = outputStream;
      final remoteTrack = sampledOutput?.getVideoTracks().firstOrNull;
      if (approved && remoteTrack != null) {
        readStage = CaptureReadStage.outputFrame;
        final outputBytes = (await remoteTrack.captureFrame().timeout(
          const Duration(seconds: 3),
        )).asUint8List();
        if (_disposed || generation != _generation) return;
        readStage = CaptureReadStage.outputAnalysis;
        final output = await (_analyzeFrame ?? _analyzer.analyze)(
          outputBytes,
        ).timeout(const Duration(seconds: 3));
        if (_disposed || generation != _generation) return;
        if (!identical(sampledOutput, outputStream) ||
            _now - capturedAt >= const Duration(milliseconds: 900)) {
          _invalidateOutput();
          return;
        }
        outputAligned = outputMatchesBody(assessment.points, output, selected);
        if (outputAligned) {
          overlayPoints = List.unmodifiable(assessment.points);
          outputPoints = List.unmodifiable(output.single);
          _lastOutputFrame = capturedAt;
        } else {
          _invalidateOutput();
        }
        if (output.length != 1) {
          _unsafe('تعذر التأكد من وجود شخص واحد في النتيجة. أعد الفحص.');
        } else if (!outputAligned) {
          _outputMismatchSince ??= _now;
          if (_now - _outputMismatchSince! > const Duration(seconds: 4)) {
            _unsafe(
              'لم تتطابق نتيجة القطعة مع وضعية جسمك. أُخفيت النتيجة؛ أعد الفحص.',
            );
          }
        } else {
          _outputMismatchSince = null;
        }
      }
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      _gate.reset();
      assessment = const CaptureAssessment(issue: CaptureIssue.unavailable);
      error = captureReadFailure(
        failure is TimeoutException ? BodyAnalysisFailure('timeout') : failure,
        readStage,
      );
      _unsafe(error!);
    } finally {
      _busy = false;
      if (!_disposed && generation == _generation) notifyListeners();
    }
  }

  void _unsafe(String message) {
    approved = false;
    _invalidateOutput();
    error = message;
    _timer?.cancel();
    analyzing = false;
    final permission = _permission;
    _permission = null;
    if (permission != null && !permission.isCompleted) {
      permission.completeError(TryonFailure(message));
    }
    _onUnsafe?.call(message);
    if (!_disposed) notifyListeners();
  }

  @override
  void cancel() {
    ++_generation;
    _timer?.cancel();
    _timer = null;
    _onUnsafe = null;
    approved = false;
    _invalidateOutput();
    _outputStream = null;
    analyzing = false;
    stream = null;
    final permission = _permission;
    _permission = null;
    if (permission != null && !permission.isCompleted) {
      permission.completeError(const TryonFailure('تم إلغاء فحص الجسم.'));
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    unawaited(_analyzer.dispose());
    super.dispose();
  }
}
