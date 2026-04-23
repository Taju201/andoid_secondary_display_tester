import 'dart:ui';

/// Maps coordinates between the desktop view and the Android display,
/// accounting for aspect-ratio-preserving scaling and letterboxing.
///
/// The view (Flutter widget area) may have a different aspect ratio than
/// the Android display. The display image is scaled to fit inside the view
/// while preserving its aspect ratio, which may result in letterbox bars
/// (horizontal or vertical).
class CoordinateMapper {
  final int displayWidth;
  final int displayHeight;
  final double viewWidth;
  final double viewHeight;

  /// The scale factor applied to the display to fit inside the view.
  late final double scale;

  /// The offset from the view's top-left to where the display image starts.
  late final Offset imageOffset;

  /// The size of the scaled display image in the view.
  late final Size imageSize;

  CoordinateMapper({
    required this.displayWidth,
    required this.displayHeight,
    required this.viewWidth,
    required this.viewHeight,
  }) {
    final scaleX = viewWidth / displayWidth;
    final scaleY = viewHeight / displayHeight;
    scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledWidth = displayWidth * scale;
    final scaledHeight = displayHeight * scale;

    // Letterbox offsets (centering the image in the view)
    final offsetX = (viewWidth - scaledWidth) / 2;
    final offsetY = (viewHeight - scaledHeight) / 2;

    imageOffset = Offset(offsetX, offsetY);
    imageSize = Size(scaledWidth, scaledHeight);
  }

  /// Map a point in the view coordinate space to Android display coordinates.
  ///
  /// Returns `null` if the point falls in the letterbox region (outside the
  /// rendered display image).
  Offset? mapToDisplay(Offset viewPoint) {
    // Subtract the letterbox offset
    final relativeX = viewPoint.dx - imageOffset.dx;
    final relativeY = viewPoint.dy - imageOffset.dy;

    // Check if the point is within the rendered image bounds
    if (relativeX < 0 ||
        relativeX > imageSize.width ||
        relativeY < 0 ||
        relativeY > imageSize.height) {
      return null;
    }

    // Scale back to display coordinates
    final displayX = relativeX / scale;
    final displayY = relativeY / scale;

    return Offset(displayX, displayY);
  }

  /// Map a point in Android display coordinates to the view coordinate space.
  ///
  /// This is the inverse of [mapToDisplay] and is useful for rendering
  /// replay visualizations.
  Offset mapToView(Offset displayPoint) {
    final viewX = displayPoint.dx * scale + imageOffset.dx;
    final viewY = displayPoint.dy * scale + imageOffset.dy;
    return Offset(viewX, viewY);
  }
}
