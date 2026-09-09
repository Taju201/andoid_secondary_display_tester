import 'dart:async';
import 'dart:typed_data';

import 'package:signals/signals.dart';

import '../models/overlay_window.dart';
import '../services/adb_service.dart';
import '../utils/frame_cropper.dart';

/// How a display's pixels are being obtained.
enum MirrorMode {
  /// `screencap -d <displayId>` against the display itself. Full fidelity.
  direct,

  /// The display could not be captured directly, so the host display is
  /// captured instead and the overlay's window region is cropped out of it.
  ///
  /// This is the only option for Developer Options simulated displays, which
  /// are windows composited onto the primary display rather than real
  /// SurfaceFlinger displays. The frame is lower fidelity: the overlay window
  /// is drawn semi-transparently, it may be scaled below the display's logical
  /// resolution, its title is drawn over the content, and anything the system
  /// draws above it lands in the crop.
  overlayCrop,
}

/// Resolves how to capture a display by cropping its host display, or null if
/// that is not possible for this display.
typedef OverlaySourceResolver = Future<OverlayCaptureSource?> Function();

/// Controls the screenshot capture loop for mirroring an Android display.
///
/// Polls `adb exec-out screencap -p -d <displayId>` at a configurable interval
/// and exposes the current frame as a reactive [Signal]. Includes automatic
/// error recovery — if a capture fails, it retries after a brief delay rather
/// than stopping the loop.
///
/// If direct capture is rejected outright by the device, the loop falls back to
/// [MirrorMode.overlayCrop] on its own rather than surfacing an error, so
/// simulated secondary displays mirror without the user having to know why
/// `screencap` refused them.
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

  /// How the current frames are being obtained.
  final mode = signal<MirrorMode>(MirrorMode.direct);

  /// Why the loop fell back to [MirrorMode.overlayCrop], if it did.
  final fallbackReason = signal<String?>(null);

  /// The overlay being cropped while in [MirrorMode.overlayCrop].
  final overlaySource = signal<OverlayCaptureSource?>(null);

  /// Capture interval (time between capture attempts).
  final captureInterval = signal<Duration>(Duration(milliseconds: 300));

  /// How often the overlay window's position and size are re-read while
  /// cropping. The user can drag or resize the overlay at any time, so a stale
  /// rect quietly mirrors the wrong pixels.
  final overlayRefreshInterval = signal<Duration>(Duration(seconds: 2));

  // ── Internal state ───────────────────────────────────────────────────────

  Timer? _captureTimer;
  String? _serial;
  int? _displayId;
  DateTime? _lastFrameTime;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;

  OverlaySourceResolver? _overlayResolver;
  bool _fallbackAttempted = false;
  DateTime? _lastOverlayRefresh;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Start capturing screenshots for the given device and display.
  ///
  /// If already capturing, stops the current loop first.
  ///
  /// [overlayResolver] is consulted only if direct capture fails. Passing null
  /// disables the crop fallback, and a direct capture failure is reported as an
  /// error like any other.
  void startCapture(
    String serial,
    int displayId, {
    OverlaySourceResolver? overlayResolver,
  }) {
    stopCapture();

    _serial = serial;
    _displayId = displayId;
    _overlayResolver = overlayResolver;
    _consecutiveErrors = 0;
    _fallbackAttempted = false;
    _lastOverlayRefresh = null;
    isCapturing.value = true;
    error.value = null;
    mode.value = MirrorMode.direct;
    fallbackReason.value = null;
    overlaySource.value = null;

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
    _overlayResolver = null;
    _fallbackAttempted = false;
    _lastOverlayRefresh = null;
    mode.value = MirrorMode.direct;
    fallbackReason.value = null;
    overlaySource.value = null;
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
      final frameData = mode.value == MirrorMode.overlayCrop
          ? await _captureCroppedFrame(serial, displayId)
          : await _adb.captureScreenshot(serial, displayId);

      if (frameData.isNotEmpty) {
        _publishFrame(frameData);
      }
    } catch (e) {
      if (await _tryFallbackToOverlayCrop(e)) return;
      _recordError(e);
    }
  }

  void _publishFrame(Uint8List frameData) {
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

  void _recordError(Object e) {
    _consecutiveErrors++;
    error.value = 'Capture failed: $e';

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      stopCapture();
      error.value =
          'Capture stopped after $_maxConsecutiveErrors consecutive errors. '
          'Last error: $e';
    }
  }

  /// Capture the host display and crop the overlay region out of it.
  Future<Uint8List> _captureCroppedFrame(String serial, int displayId) async {
    final source = await _currentOverlaySource();
    if (source == null) {
      throw StateError(
        'Display $displayId is no longer available as an overlay window',
      );
    }

    final hostFrame = await _adb.captureScreenshot(
      serial,
      source.hostDisplayId,
    );

    return cropHostFrame(
      hostFrame,
      cropRect: source.cropRect,
      hostWidth: source.hostWidth,
      hostHeight: source.hostHeight,
    );
  }

  /// The overlay geometry to crop with, re-read once [overlayRefreshInterval]
  /// has elapsed so that moving or resizing the overlay is picked up.
  Future<OverlayCaptureSource?> _currentOverlaySource() async {
    final resolver = _overlayResolver;
    if (resolver == null) return overlaySource.value;

    final last = _lastOverlayRefresh;
    final due = last == null ||
        DateTime.now().difference(last) >= overlayRefreshInterval.value;
    if (!due) return overlaySource.value;

    _lastOverlayRefresh = DateTime.now();
    final refreshed = await resolver();
    if (refreshed != null) {
      overlaySource.value = refreshed;
    }
    return refreshed ?? overlaySource.value;
  }

  /// Switch to cropping the host display after a direct capture failed.
  ///
  /// Returns true if the mode was switched, in which case the failure is not
  /// reported — the next tick captures through the new mode instead.
  Future<bool> _tryFallbackToOverlayCrop(Object failure) async {
    if (mode.value == MirrorMode.overlayCrop) return false;
    if (_fallbackAttempted) return false;

    final resolver = _overlayResolver;
    if (resolver == null) return false;

    _fallbackAttempted = true;

    OverlayCaptureSource? source;
    try {
      source = await resolver();
    } catch (_) {
      return false;
    }
    if (source == null) return false;
    if (!isCapturing.value) return false;

    _lastOverlayRefresh = DateTime.now();
    overlaySource.value = source;
    mode.value = MirrorMode.overlayCrop;
    fallbackReason.value =
        failure is ScreencapException ? failure.reason : failure.toString();
    error.value = null;
    _consecutiveErrors = 0;

    return true;
  }

  /// Clean up resources.
  void dispose() {
    stopCapture();
  }
}
