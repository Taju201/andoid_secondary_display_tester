import 'dart:ui';

import 'package:signals/signals.dart';

import '../services/adb_service.dart';
import '../utils/coordinate_mapper.dart';

/// Handles user touch interactions on the mirrored display view.
///
/// Maps view-space coordinates to Android display coordinates using
/// [CoordinateMapper], then dispatches the appropriate ADB input commands.
/// Also exposes signals for visual feedback (tap ripples, swipe trails).
class InteractionController {
  final AdbService _adb;

  InteractionController(this._adb);

  // ── Signals ──────────────────────────────────────────────────────────────

  /// The last tap point in view coordinates (for ripple animation).
  final lastTapPoint = signal<Offset?>(null);

  /// The current swipe path in view coordinates (for trail rendering).
  final currentSwipePath = signal<List<Offset>>([]);

  /// Whether an input command is currently being sent.
  final isSending = signal<bool>(false);

  /// The last error from an input command, or null.
  final error = signal<String?>(null);

  // ── Internal state ───────────────────────────────────────────────────────

  Offset? _swipeStartDisplay;
  DateTime? _swipeStartTime;

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Handle a tap at the given view-space position.
  ///
  /// Returns the mapped display coordinates, or null if the tap was in
  /// the letterbox region.
  Future<Offset?> handleTap(
    Offset viewPoint,
    CoordinateMapper mapper,
    String serial,
    int displayId,
  ) async {
    final displayPoint = mapper.mapToDisplay(viewPoint);
    if (displayPoint == null) return null;

    lastTapPoint.value = viewPoint;
    isSending.value = true;
    error.value = null;

    try {
      await _adb.inputTap(
        serial,
        displayId,
        displayPoint.dx,
        displayPoint.dy,
      );
      return displayPoint;
    } catch (e) {
      error.value = 'Tap failed: $e';
      return null;
    } finally {
      isSending.value = false;
    }
  }

  /// Start tracking a swipe gesture.
  void handleSwipeStart(Offset viewPoint, CoordinateMapper mapper) {
    final displayPoint = mapper.mapToDisplay(viewPoint);
    if (displayPoint == null) return;

    _swipeStartDisplay = displayPoint;
    _swipeStartTime = DateTime.now();
    currentSwipePath.value = [viewPoint];
  }

  /// Update the swipe gesture path (for visual trail).
  void handleSwipeUpdate(Offset viewPoint) {
    if (_swipeStartDisplay == null) return;
    currentSwipePath.value = [...currentSwipePath.value, viewPoint];
  }

  /// End the swipe gesture and send the command to the device.
  ///
  /// Returns the start and end display coordinates as a pair, or null
  /// if the swipe was invalid.
  Future<(Offset start, Offset end)?> handleSwipeEnd(
    Offset viewPoint,
    CoordinateMapper mapper,
    String serial,
    int displayId,
  ) async {
    final startDisplay = _swipeStartDisplay;
    final startTime = _swipeStartTime;

    if (startDisplay == null || startTime == null) {
      currentSwipePath.value = [];
      return null;
    }

    final endDisplay = mapper.mapToDisplay(viewPoint);
    if (endDisplay == null) {
      currentSwipePath.value = [];
      _swipeStartDisplay = null;
      _swipeStartTime = null;
      return null;
    }

    final durationMs =
        DateTime.now().difference(startTime).inMilliseconds.clamp(50, 10000);

    isSending.value = true;
    error.value = null;

    try {
      await _adb.inputSwipe(
        serial,
        displayId,
        startDisplay.dx,
        startDisplay.dy,
        endDisplay.dx,
        endDisplay.dy,
        durationMs,
      );
      return (startDisplay, endDisplay);
    } catch (e) {
      error.value = 'Swipe failed: $e';
      return null;
    } finally {
      isSending.value = false;
      currentSwipePath.value = [];
      _swipeStartDisplay = null;
      _swipeStartTime = null;
    }
  }

  /// Handle a long-press at the given view-space position.
  ///
  /// Returns the mapped display coordinates, or null if the press was
  /// in the letterbox region.
  Future<Offset?> handleLongPress(
    Offset viewPoint,
    CoordinateMapper mapper,
    String serial,
    int displayId, {
    int durationMs = 1000,
  }) async {
    final displayPoint = mapper.mapToDisplay(viewPoint);
    if (displayPoint == null) return null;

    lastTapPoint.value = viewPoint;
    isSending.value = true;
    error.value = null;

    try {
      await _adb.inputLongPress(
        serial,
        displayId,
        displayPoint.dx,
        displayPoint.dy,
        durationMs,
      );
      return displayPoint;
    } catch (e) {
      error.value = 'Long press failed: $e';
      return null;
    } finally {
      isSending.value = false;
    }
  }

  /// Clear visual feedback state.
  void clearFeedback() {
    lastTapPoint.value = null;
    currentSwipePath.value = [];
  }
}
