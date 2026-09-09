import 'dart:ui';

/// A Developer Options "simulated secondary display" as reported by the
/// `OverlayDisplayAdapter` section of `dumpsys display`.
///
/// These displays are not real SurfaceFlinger displays — the system composites
/// them as a floating window on top of the host (primary) display. That means
/// `screencap -d <id>` cannot capture them, and the only way to see their
/// content is to capture the host display and crop out [windowRect].
class OverlayWindow {
  /// The overlay's own number, e.g. 1 for `Overlay #1` / `overlay:1`.
  final int number;

  /// The logical Android display id this overlay is exposed as, e.g. 2.
  ///
  /// Null when `dumpsys` did not expose a `uniqueId` → `displayId` mapping.
  final int? displayId;

  /// Where the overlay window sits on the host display, in host pixels.
  final Rect windowRect;

  /// The overlay's logical resolution — the coordinate space that
  /// `input -d <displayId>` expects.
  final int logicalWidth;
  final int logicalHeight;
  final int density;

  /// Whether the system currently has the overlay window on screen. A hidden
  /// overlay cannot be captured by cropping the host display.
  final bool visible;

  const OverlayWindow({
    required this.number,
    required this.displayId,
    required this.windowRect,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.density,
    required this.visible,
  });

  /// The unique id the display subsystem uses for this overlay.
  String get uniqueId => 'overlay:$number';

  /// How much the window is scaled down from the logical resolution.
  ///
  /// 1.0 means the crop is pixel-for-pixel with the logical display; 0.5 means
  /// the mirrored frame carries half the detail of the real display.
  double get renderScale {
    if (logicalWidth == 0) return 1.0;
    return windowRect.width / logicalWidth;
  }

  @override
  String toString() =>
      'OverlayWindow(#$number, displayId=$displayId, '
      'window=$windowRect, logical=${logicalWidth}x$logicalHeight, '
      'visible=$visible)';
}

/// Everything the mirror loop needs to capture an overlay display by cropping
/// its host display's screenshot.
class OverlayCaptureSource {
  /// The display to actually run `screencap` against — the host display the
  /// overlay window is composited onto.
  final int hostDisplayId;

  /// The host display's logical size, used to rescale [cropRect] if the
  /// screenshot comes back at a different resolution than `dumpsys` reported.
  final int hostWidth;
  final int hostHeight;

  /// The region of the host screenshot that holds the overlay's content.
  final Rect cropRect;

  /// The overlay this source was derived from.
  final OverlayWindow overlay;

  const OverlayCaptureSource({
    required this.hostDisplayId,
    required this.hostWidth,
    required this.hostHeight,
    required this.cropRect,
    required this.overlay,
  });

  @override
  String toString() =>
      'OverlayCaptureSource(host=$hostDisplayId ${hostWidth}x$hostHeight, '
      'crop=$cropRect)';
}
