import 'dart:async';
import 'dart:typed_data';

import 'package:signals/signals.dart';

import '../services/adb_service.dart';

/// Controls the screenshot capture loop for mirroring an Android display.
///
/// Polls `adb exec-out screencap -p -d <displayId>` at a configurable interval
/// and exposes the current frame as a reactive [Signal]. Includes automatic
/// error recovery — if a capture fails, it retries after a brief delay rather
/// than stopping the loop.
class DisplayMirrorController {
  final AdbService _adb;

  DisplayMirrorController(this._adb);

  // ── Signals ──────────────────────────────────────────────────────────────

  /// The current screenshot frame as raw PNG bytes, or null if none captured.
  final currentFrame = signal<Uint8List?>(null);

  /// Whether the capture loop is currently running.
  final isCapturing = signal<bool>(false);

  /// Approximate frames per second being captured.
  final fps = signal<double>(0.0);

  /// The last capture error, or null if the last capture succeeded.
  final error = signal<String?>(null);

  /// Capture interval (time between capture attempts).
  final captureInterval = signal<Duration>(Duration(milliseconds: 300));

  // ── Internal state ───────────────────────────────────────────────────────

  Timer? _captureTimer;
  String? _serial;
  int? _displayId;
  DateTime? _lastFrameTime;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Start capturing screenshots for the given device and display.
  ///
  /// If already capturing, stops the current loop first.
  void startCapture(String serial, int displayId) {
    stopCapture();

    _serial = serial;
    _displayId = displayId;
    _consecutiveErrors = 0;
    isCapturing.value = true;
    error.value = null;

    _scheduleNextCapture();
  }

  /// Stop the capture loop and reset state.
  void stopCapture() {
    _captureTimer?.cancel();
    _captureTimer = null;
    isCapturing.value = false;
    fps.value = 0.0;
    _serial = null;
    _displayId = null;
    _lastFrameTime = null;
    _consecutiveErrors = 0;
  }

  /// Set the capture interval and reschedule if currently capturing.
  void setCaptureInterval(Duration interval) {
    captureInterval.value = interval;
    // The next scheduled capture will pick up the new interval
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  void _scheduleNextCapture() {
    if (!isCapturing.value) return;

    _captureTimer = Timer(captureInterval.value, () async {
      await _captureFrame();
      _scheduleNextCapture();
    });
  }

  Future<void> _captureFrame() async {
    final serial = _serial;
    final displayId = _displayId;

    if (serial == null || displayId == null || !isCapturing.value) return;

    try {
      final frameData = await _adb.captureScreenshot(serial, displayId);

      if (frameData.isNotEmpty) {
        currentFrame.value = frameData;
        error.value = null;
        _consecutiveErrors = 0;

        // Calculate FPS
        final now = DateTime.now();
        if (_lastFrameTime != null) {
          final delta = now.difference(_lastFrameTime!).inMilliseconds;
          if (delta > 0) {
            fps.value = 1000.0 / delta;
          }
        }
        _lastFrameTime = now;
      }
    } catch (e) {
      _consecutiveErrors++;
      error.value = 'Capture failed: $e';

      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        stopCapture();
        error.value =
            'Capture stopped after $_maxConsecutiveErrors consecutive errors. '
            'Last error: $e';
      }
    }
  }

  /// Clean up resources.
  void dispose() {
    stopCapture();
  }
}
