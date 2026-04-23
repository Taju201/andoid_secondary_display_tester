import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:signals/signals.dart';

import '../models/recording.dart';
import '../models/touch_action.dart';
import '../services/adb_service.dart';

/// Controls touch interaction recording, saving, loading, and replay.
///
/// When recording is active, touch actions are timestamped relative to the
/// recording start time. During replay, the controller waits the appropriate
/// delta between each action to preserve original timing.
class RecordingController {
  // ── Signals ──────────────────────────────────────────────────────────────

  /// Whether recording is currently active.
  final isRecording = signal<bool>(false);

  /// Whether a replay is currently in progress.
  final isReplaying = signal<bool>(false);

  /// The current recording being built or loaded.
  final currentRecording = signal<Recording?>(null);

  /// Replay progress from 0.0 to 1.0.
  final replayProgress = signal<double>(0.0);

  /// The last error, or null.
  final error = signal<String?>(null);

  // ── Internal state ───────────────────────────────────────────────────────

  DateTime? _recordingStartTime;
  Completer<void>? _replayCanceller;

  // ── Recording ────────────────────────────────────────────────────────────

  /// Start a new recording for the given display.
  void startRecording(int displayId, int displayWidth, int displayHeight) {
    final recording = Recording(
      name: 'Recording ${DateTime.now().toIso8601String()}',
      createdAt: DateTime.now(),
      displayId: displayId,
      displayWidth: displayWidth,
      displayHeight: displayHeight,
    );

    currentRecording.value = recording;
    _recordingStartTime = DateTime.now();
    isRecording.value = true;
    error.value = null;
  }

  /// Stop the current recording.
  void stopRecording() {
    isRecording.value = false;
    _recordingStartTime = null;
  }

  /// Add a touch action to the current recording.
  ///
  /// The [timestampMs] is calculated automatically relative to the recording
  /// start time.
  void addAction(TouchAction action) {
    final recording = currentRecording.value;
    if (recording == null || !isRecording.value) return;

    final timestampMs = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
        : 0;

    final timedAction = TouchAction(
      type: action.type,
      x: action.x,
      y: action.y,
      endX: action.endX,
      endY: action.endY,
      durationMs: action.durationMs,
      timestampMs: timestampMs,
    );

    recording.actions.add(timedAction);
    // Trigger signal update by reassigning
    currentRecording.value = recording;
  }

  /// Clear the current recording.
  void clearRecording() {
    currentRecording.value = null;
    isRecording.value = false;
    _recordingStartTime = null;
  }

  // ── Save / Load ──────────────────────────────────────────────────────────

  /// Save the current recording to a JSON file.
  Future<void> saveToFile(String path) async {
    final recording = currentRecording.value;
    if (recording == null) {
      error.value = 'No recording to save';
      return;
    }

    try {
      final json = jsonEncode(recording.toJson());
      await File(path).writeAsString(json);
      error.value = null;
    } catch (e) {
      error.value = 'Failed to save recording: $e';
    }
  }

  /// Load a recording from a JSON file.
  Future<void> loadFromFile(String path) async {
    try {
      final contents = await File(path).readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      currentRecording.value = Recording.fromJson(json);
      error.value = null;
    } catch (e) {
      error.value = 'Failed to load recording: $e';
    }
  }

  // ── Replay ───────────────────────────────────────────────────────────────

  /// Replay the current recording on the given device and display.
  ///
  /// Actions are dispatched with the original timing preserved. The replay
  /// can be cancelled by calling [stopReplay].
  Future<void> replay(AdbService adb, String serial) async {
    final recording = currentRecording.value;
    if (recording == null || recording.actions.isEmpty) {
      error.value = 'No recording to replay';
      return;
    }

    isReplaying.value = true;
    replayProgress.value = 0.0;
    error.value = null;
    _replayCanceller = Completer<void>();

    try {
      for (var i = 0; i < recording.actions.length; i++) {
        // Check if replay was cancelled
        if (_replayCanceller?.isCompleted ?? true) break;

        final action = recording.actions[i];

        // Wait for the appropriate time delta
        if (i > 0) {
          final prevAction = recording.actions[i - 1];
          final delta = action.timestampMs - prevAction.timestampMs;
          if (delta > 0) {
            await Future.any([
              Future.delayed(Duration(milliseconds: delta)),
              _replayCanceller!.future,
            ]);
            if (_replayCanceller?.isCompleted ?? true) break;
          }
        } else if (action.timestampMs > 0) {
          // Wait for initial delay
          await Future.any([
            Future.delayed(Duration(milliseconds: action.timestampMs)),
            _replayCanceller!.future,
          ]);
          if (_replayCanceller?.isCompleted ?? true) break;
        }

        // Execute the action
        switch (action.type) {
          case TouchActionType.tap:
            await adb.inputTap(
              serial,
              recording.displayId,
              action.x,
              action.y,
            );
          case TouchActionType.swipe:
            await adb.inputSwipe(
              serial,
              recording.displayId,
              action.x,
              action.y,
              action.endX!,
              action.endY!,
              action.durationMs ?? 300,
            );
          case TouchActionType.longPress:
            await adb.inputLongPress(
              serial,
              recording.displayId,
              action.x,
              action.y,
              action.durationMs ?? 1000,
            );
        }

        replayProgress.value = (i + 1) / recording.actions.length;
      }
    } catch (e) {
      error.value = 'Replay failed: $e';
    } finally {
      isReplaying.value = false;
      replayProgress.value = 0.0;
      _replayCanceller = null;
    }
  }

  /// Cancel the current replay.
  void stopReplay() {
    if (_replayCanceller != null && !_replayCanceller!.isCompleted) {
      _replayCanceller!.complete();
    }
  }
}
