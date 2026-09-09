import 'dart:typed_data';
import 'dart:ui' as ui;

/// Work out which region of a host-display screenshot holds an overlay
/// display's content.
///
/// [cropRect] comes from `dumpsys display`, expressed in the host display's
/// logical pixels. The screenshot is normally the same size, but a device can
/// hand back a differently sized image (a scaled capture, a stale size after
/// rotation), so the rect is rescaled to the actual image before use and then
/// clamped to the image bounds.
///
/// Returns `null` when the rect does not overlap the image at all — an overlay
/// that has been dragged off-screen, or a size mismatch large enough that the
/// mapping is meaningless.
ui.Rect? computeCropSourceRect({
  required ui.Rect cropRect,
  required int hostWidth,
  required int hostHeight,
  required int imageWidth,
  required int imageHeight,
}) {
  if (hostWidth <= 0 || hostHeight <= 0 || imageWidth <= 0 || imageHeight <= 0) {
    return null;
  }

  final scaleX = imageWidth / hostWidth;
  final scaleY = imageHeight / hostHeight;

  final scaled = ui.Rect.fromLTWH(
    cropRect.left * scaleX,
    cropRect.top * scaleY,
    cropRect.width * scaleX,
    cropRect.height * scaleY,
  );

  final bounds = ui.Rect.fromLTWH(
    0,
    0,
    imageWidth.toDouble(),
    imageHeight.toDouble(),
  );
  final clamped = scaled.intersect(bounds);

  if (clamped.width < 1 || clamped.height < 1) return null;
  return clamped;
}

/// Thrown when a host frame cannot be cropped down to the overlay region.
class FrameCropException implements Exception {
  final String message;

  const FrameCropException(this.message);

  @override
  String toString() => message;
}

/// Crop the overlay region out of a host-display screenshot and re-encode it
/// as a PNG.
///
/// Re-encoding rather than exposing a `ui.Image` keeps both mirror modes on a
/// single render path (`Image.memory`), which avoids having to reason about
/// image handle lifetimes while a frame is still on screen.
Future<Uint8List> cropHostFrame(
  Uint8List hostPng, {
  required ui.Rect cropRect,
  required int hostWidth,
  required int hostHeight,
}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(hostPng);
  ui.ImageDescriptor descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
  } catch (_) {
    buffer.dispose();
    rethrow;
  }

  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final source = frame.image;

  try {
    final sourceRect = computeCropSourceRect(
      cropRect: cropRect,
      hostWidth: hostWidth,
      hostHeight: hostHeight,
      imageWidth: source.width,
      imageHeight: source.height,
    );

    if (sourceRect == null) {
      throw FrameCropException(
        'Overlay window $cropRect does not overlap the '
        '${source.width}x${source.height} host frame',
      );
    }

    final width = sourceRect.width.round();
    final height = sourceRect.height.round();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      source,
      sourceRect,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();

    final cropped = await picture.toImage(width, height);
    picture.dispose();

    try {
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw const FrameCropException('Failed to encode cropped frame as PNG');
      }
      return data.buffer.asUint8List();
    } finally {
      cropped.dispose();
    }
  } finally {
    source.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}
