import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/display_mirror_controller.dart';

/// Renders the mirrored Android display screenshot with FPS overlay.
class MirrorView extends StatelessWidget {
  final DisplayMirrorController mirrorController;

  const MirrorView({super.key, required this.mirrorController});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF010409),
      child: Watch((context) {
        final frame = mirrorController.currentFrame.value;
        final capturing = mirrorController.isCapturing.value;
        final currentFps = mirrorController.fps.value;
        final err = mirrorController.error.value;

        if (frame == null) {
          return _buildWaitingState(capturing, err);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Image.memory(
                frame,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
            if (capturing)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${currentFps.toStringAsFixed(1)} FPS',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildWaitingState(bool capturing, String? error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (capturing) ...[
            const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(height: 16),
            Text('Capturing first frame...', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4))),
          ] else if (error != null) ...[
            Icon(Icons.error_outline, size: 40, color: const Color(0xFFF85149).withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(error, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
            ),
          ] else ...[
            Icon(Icons.screenshot_monitor_outlined, size: 64, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 16),
            Text('Select a display to start mirroring', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.25))),
          ],
        ],
      ),
    );
  }
}
