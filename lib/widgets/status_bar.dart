import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/device_session.dart';
import '../controllers/display_mirror_controller.dart';
import '../controllers/recording_controller.dart';

/// Bottom status bar showing ADB version, device, display, FPS, and recording state.
class StatusBar extends StatelessWidget {
  final DeviceSession deviceSession;
  final DisplayMirrorController mirrorController;
  final RecordingController recordingController;

  const StatusBar({
    super.key,
    required this.deviceSession,
    required this.mirrorController,
    required this.recordingController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF0D1117),
      child: Row(
        children: [
          // ADB version
          Watch((context) {
            final valid = deviceSession.adbValid.value;
            final version = deviceSession.adbVersion.value;
            return _statusItem(
              icon: Icons.terminal,
              iconColor: valid ? const Color(0xFF3FB950) : const Color(0xFFF85149),
              text: valid ? 'ADB v$version' : 'ADB N/A',
            );
          }),

          _divider(),

          // Device
          Watch((context) {
            final device = deviceSession.selectedDevice.value;
            return _statusItem(
              icon: Icons.phone_android,
              text: device?.displayName ?? 'No device',
            );
          }),

          _divider(),

          // Display
          Watch((context) {
            final display = deviceSession.selectedDisplay.value;
            return _statusItem(
              icon: Icons.monitor,
              text: display != null ? 'Display ${display.id} (${display.resolution})' : 'No display',
            );
          }),

          const Spacer(),

          // FPS
          Watch((context) {
            final fps = mirrorController.fps.value;
            final capturing = mirrorController.isCapturing.value;
            if (!capturing) return const SizedBox.shrink();
            return _statusItem(
              icon: Icons.speed,
              text: '${fps.toStringAsFixed(1)} FPS',
            );
          }),

          _divider(),

          // Recording indicator
          Watch((context) {
            final recording = recordingController.isRecording.value;
            final replaying = recordingController.isReplaying.value;

            if (recording) {
              return _statusItem(
                icon: Icons.fiber_manual_record,
                iconColor: const Color(0xFFF85149),
                text: 'REC',
              );
            }
            if (replaying) {
              return _statusItem(
                icon: Icons.play_arrow,
                iconColor: const Color(0xFF6C5CE7),
                text: 'REPLAY',
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _statusItem({
    required IconData icon,
    Color? iconColor,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: iconColor ?? Colors.white.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
        ),
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 1,
        height: 12,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
