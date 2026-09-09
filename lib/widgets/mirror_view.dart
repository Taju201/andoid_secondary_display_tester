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
        final mode = mirrorController.mode.value;

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
            if (mode == MirrorMode.overlayCrop)
              Positioned(
                top: 8,
                left: 8,
                child: _OverlayModeBadge(
                  reason: mirrorController.fallbackReason.value,
                  scale: mirrorController.overlaySource.value?.overlay
                      .renderScale,
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

/// Badge shown while the mirror is cropping the overlay out of the host
/// display, so a degraded frame is never mistaken for a direct capture.
class _OverlayModeBadge extends StatelessWidget {
  final String? reason;
  final double? scale;

  const _OverlayModeBadge({this.reason, this.scale});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFD29922);

    final details = <String>[
      if (reason != null) 'Direct capture failed: $reason',
      'Cropped from the primary display screenshot. The overlay window is '
          'drawn semi-transparently and its title sits over the content, so '
          'colors and the top edge are not exact.',
      if (scale != null && scale! < 0.99)
        'The overlay is scaled to ${(scale! * 100).round()}% of the display '
            'resolution, so the frame carries less detail than the display.',
      'Touch input is unaffected — it still targets the display at its full '
          'resolution.',
    ];

    return Tooltip(
      message: details.join('\n\n'),
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.crop, size: 12, color: amber),
            const SizedBox(width: 6),
            const Text(
              'Overlay crop',
              style: TextStyle(
                fontSize: 11,
                color: amber,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (scale != null && scale! < 0.99) ...[
              const SizedBox(width: 6),
              Text(
                '${(scale! * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: amber.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
