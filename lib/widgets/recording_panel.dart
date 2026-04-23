import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/device_session.dart';
import '../controllers/recording_controller.dart';
import '../services/adb_service.dart';

/// Recording controls and action list panel.
class RecordingPanel extends StatelessWidget {
  final RecordingController recordingController;
  final DeviceSession deviceSession;
  final AdbService adbService;

  const RecordingPanel({
    super.key,
    required this.recordingController,
    required this.deviceSession,
    required this.adbService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Text(
            'RECORDING',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Watch((context) {
            final recording = recordingController.isRecording.value;
            final replaying = recordingController.isReplaying.value;
            final hasRecording = recordingController.currentRecording.value != null;
            final hasDevice = deviceSession.hasDevice.value;
            final hasDisplay = deviceSession.hasDisplay.value;
            final canRecord = hasDevice && hasDisplay && !replaying;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Record / Stop button
                SizedBox(
                  height: 36,
                  child: recording
                      ? ElevatedButton.icon(
                          onPressed: () => recordingController.stopRecording(),
                          icon: const Icon(Icons.stop, size: 16),
                          label: const Text('Stop', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF85149),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: canRecord ? _startRecording : null,
                          icon: const Icon(Icons.fiber_manual_record, size: 14, color: Color(0xFFF85149)),
                          label: const Text('Record', style: TextStyle(fontSize: 13)),
                        ),
                ),

                const SizedBox(height: 8),

                // Replay button
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: hasRecording && hasDevice && !recording
                        ? (replaying ? _stopReplay : _replay)
                        : null,
                    icon: Icon(replaying ? Icons.stop : Icons.play_arrow, size: 16),
                    label: Text(replaying ? 'Stop' : 'Replay', style: const TextStyle(fontSize: 12)),
                  ),
                ),

                const SizedBox(height: 4),

                // Save / Load row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: hasRecording ? () => _save(context) : null,
                          icon: const Icon(Icons.save_outlined, size: 14),
                          label: const Text('Save', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: !recording ? () => _load(context) : null,
                          icon: const Icon(Icons.folder_open_outlined, size: 14),
                          label: const Text('Load', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                ),

                // Replay progress
                if (replaying) ...[
                  const SizedBox(height: 8),
                  Watch((context) {
                    final progress = recordingController.replayProgress.value;
                    return LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                    );
                  }),
                ],
              ],
            );
          }),
        ),

        const SizedBox(height: 8),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),

        // Action list
        Expanded(
          child: Watch((context) {
            final recording = recordingController.currentRecording.value;
            final actions = recording?.actions ?? [];

            if (actions.isEmpty) {
              return Center(
                child: Text(
                  'No actions recorded',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.2)),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}.',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ),
                      Icon(
                        _iconForAction(action.type),
                        size: 12,
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          action.summary,
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${action.timestampMs}ms',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.25)),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  IconData _iconForAction(dynamic type) {
    switch (type.toString()) {
      case 'TouchActionType.tap':
        return Icons.touch_app;
      case 'TouchActionType.swipe':
        return Icons.swipe;
      case 'TouchActionType.longPress':
        return Icons.pan_tool;
      default:
        return Icons.circle;
    }
  }

  void _startRecording() {
    final display = deviceSession.selectedDisplay.value;
    if (display == null) return;
    recordingController.startRecording(display.id, display.width, display.height);
  }

  void _stopReplay() {
    recordingController.stopReplay();
  }

  void _replay() async {
    final device = deviceSession.selectedDevice.value;
    if (device == null) return;
    await recordingController.replay(adbService, device.serial);
  }

  void _save(BuildContext context) async {
    // Simple file name dialog
    final controller = TextEditingController(text: 'recording.json');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Recording'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'File name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final dir = Directory.current.path;
      await recordingController.saveToFile('$dir/$result');
    }
  }

  void _load(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Recording'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'File path'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Load'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await recordingController.loadFromFile(result);
    }
  }
}
