import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/device_session.dart';
import '../controllers/display_mirror_controller.dart';
import '../controllers/interaction_controller.dart';
import '../controllers/recording_controller.dart';
import '../models/touch_action.dart';
import '../utils/coordinate_mapper.dart';

/// Transparent gesture overlay on the mirror view for touch interaction.
///
/// Detects tap, pan (swipe), and long-press gestures, maps them to display
/// coordinates, and sends ADB input commands. Also provides visual feedback.
class InteractionOverlay extends StatefulWidget {
  final DeviceSession deviceSession;
  final DisplayMirrorController mirrorController;
  final InteractionController interactionController;
  final RecordingController recordingController;

  const InteractionOverlay({
    super.key,
    required this.deviceSession,
    required this.mirrorController,
    required this.interactionController,
    required this.recordingController,
  });

  @override
  State<InteractionOverlay> createState() => _InteractionOverlayState();
}

class _InteractionOverlayState extends State<InteractionOverlay>
    with SingleTickerProviderStateMixin {
  final _viewKey = GlobalKey();
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  CoordinateMapper? _getMapper() {
    final display = widget.deviceSession.selectedDisplay.value;
    if (display == null) return null;

    final renderBox =
        _viewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    return CoordinateMapper(
      displayWidth: display.width,
      displayHeight: display.height,
      viewWidth: renderBox.size.width,
      viewHeight: renderBox.size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _viewKey,
      behavior: HitTestBehavior.translucent,
      onTapUp: _onTapUp,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onLongPressStart: _onLongPressStart,
      child: Watch((context) {
        final tapPoint = widget.interactionController.lastTapPoint.value;
        final swipePath = widget.interactionController.currentSwipePath.value;

        return CustomPaint(
          painter: _FeedbackPainter(
            tapPoint: tapPoint,
            swipePath: swipePath,
            rippleProgress: _rippleController.value,
          ),
          size: Size.infinite,
        );
      }),
    );
  }

  void _onTapUp(TapUpDetails details) async {
    final mapper = _getMapper();
    if (mapper == null) return;

    final device = widget.deviceSession.selectedDevice.value;
    final display = widget.deviceSession.selectedDisplay.value;
    if (device == null || display == null) return;

    _rippleController.forward(from: 0.0);

    final displayPoint = await widget.interactionController.handleTap(
      details.localPosition,
      mapper,
      device.serial,
      display.id,
    );

    if (displayPoint != null && widget.recordingController.isRecording.value) {
      widget.recordingController.addAction(TouchAction(
        type: TouchActionType.tap,
        x: displayPoint.dx,
        y: displayPoint.dy,
        timestampMs: 0, // Will be overridden by controller
      ));
    }
  }

  void _onPanStart(DragStartDetails details) {
    final mapper = _getMapper();
    if (mapper == null) return;
    widget.interactionController.handleSwipeStart(
      details.localPosition,
      mapper,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    widget.interactionController.handleSwipeUpdate(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) async {
    final mapper = _getMapper();
    if (mapper == null) return;

    final device = widget.deviceSession.selectedDevice.value;
    final display = widget.deviceSession.selectedDisplay.value;
    if (device == null || display == null) return;

    // Get the last position from the swipe path
    final path = widget.interactionController.currentSwipePath.value;
    if (path.isEmpty) return;
    final lastPoint = path.last;

    final result = await widget.interactionController.handleSwipeEnd(
      lastPoint,
      mapper,
      device.serial,
      display.id,
    );

    if (result != null && widget.recordingController.isRecording.value) {
      final (start, end) = result;
      widget.recordingController.addAction(TouchAction(
        type: TouchActionType.swipe,
        x: start.dx,
        y: start.dy,
        endX: end.dx,
        endY: end.dy,
        durationMs: 300,
        timestampMs: 0,
      ));
    }
  }

  void _onLongPressStart(LongPressStartDetails details) async {
    final mapper = _getMapper();
    if (mapper == null) return;

    final device = widget.deviceSession.selectedDevice.value;
    final display = widget.deviceSession.selectedDisplay.value;
    if (device == null || display == null) return;

    final displayPoint = await widget.interactionController.handleLongPress(
      details.localPosition,
      mapper,
      device.serial,
      display.id,
    );

    if (displayPoint != null && widget.recordingController.isRecording.value) {
      widget.recordingController.addAction(TouchAction(
        type: TouchActionType.longPress,
        x: displayPoint.dx,
        y: displayPoint.dy,
        durationMs: 1000,
        timestampMs: 0,
      ));
    }
  }
}

/// Custom painter for tap ripple and swipe trail visual feedback.
class _FeedbackPainter extends CustomPainter {
  final Offset? tapPoint;
  final List<Offset> swipePath;
  final double rippleProgress;

  _FeedbackPainter({
    this.tapPoint,
    this.swipePath = const [],
    this.rippleProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw swipe trail
    if (swipePath.length >= 2) {
      final paint = Paint()
        ..color = const Color(0xFF6C5CE7).withValues(alpha: 0.6)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(swipePath.first.dx, swipePath.first.dy);
      for (final point in swipePath.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw tap ripple
    if (tapPoint != null && rippleProgress > 0) {
      final opacity = (1.0 - rippleProgress).clamp(0.0, 1.0);
      final radius = 20 + (30 * rippleProgress);

      final paint = Paint()
        ..color = const Color(0xFF6C5CE7).withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(tapPoint!, radius, paint);

      final borderPaint = Paint()
        ..color = const Color(0xFF6C5CE7).withValues(alpha: opacity * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(tapPoint!, radius, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_FeedbackPainter oldDelegate) {
    return tapPoint != oldDelegate.tapPoint ||
        swipePath != oldDelegate.swipePath ||
        rippleProgress != oldDelegate.rippleProgress;
  }
}
