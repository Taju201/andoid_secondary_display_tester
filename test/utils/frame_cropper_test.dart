import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:andoid_secondary_display_tester/utils/frame_cropper.dart';

void main() {
  group('computeCropSourceRect', () {
    test('passes the rect through when the screenshot matches the host size',
        () {
      final rect = computeCropSourceRect(
        cropRect: const Rect.fromLTWH(74, 381, 720, 480),
        hostWidth: 1080,
        hostHeight: 2404,
        imageWidth: 1080,
        imageHeight: 2404,
      );

      expect(rect, const Rect.fromLTWH(74, 381, 720, 480));
    });

    test('rescales when the screenshot comes back at a different size', () {
      final rect = computeCropSourceRect(
        cropRect: const Rect.fromLTWH(100, 200, 400, 300),
        hostWidth: 1080,
        hostHeight: 2400,
        imageWidth: 540,
        imageHeight: 1200,
      );

      expect(rect, const Rect.fromLTWH(50, 100, 200, 150));
    });

    test('clamps a window that hangs off the right edge', () {
      final rect = computeCropSourceRect(
        cropRect: const Rect.fromLTWH(900, 100, 400, 300),
        hostWidth: 1080,
        hostHeight: 2400,
        imageWidth: 1080,
        imageHeight: 2400,
      );

      expect(rect, const Rect.fromLTWH(900, 100, 180, 300));
    });

    test('clamps a window dragged past the top-left corner', () {
      final rect = computeCropSourceRect(
        cropRect: const Rect.fromLTWH(-50, -20, 400, 300),
        hostWidth: 1080,
        hostHeight: 2400,
        imageWidth: 1080,
        imageHeight: 2400,
      );

      expect(rect, const Rect.fromLTWH(0, 0, 350, 280));
    });

    test('returns null when the window is entirely off-screen', () {
      final rect = computeCropSourceRect(
        cropRect: const Rect.fromLTWH(2000, 100, 400, 300),
        hostWidth: 1080,
        hostHeight: 2400,
        imageWidth: 1080,
        imageHeight: 2400,
      );

      expect(rect, isNull);
    });

    test('returns null when the overlap is smaller than a pixel', () {
      final rect = computeCropSourceRect(
        cropRect: const Rect.fromLTWH(1079.5, 100, 400, 300),
        hostWidth: 1080,
        hostHeight: 2400,
        imageWidth: 1080,
        imageHeight: 2400,
      );

      expect(rect, isNull);
    });

    test('returns null for a degenerate host or image size', () {
      const crop = Rect.fromLTWH(0, 0, 100, 100);

      expect(
        computeCropSourceRect(
          cropRect: crop,
          hostWidth: 0,
          hostHeight: 2400,
          imageWidth: 1080,
          imageHeight: 2400,
        ),
        isNull,
      );
      expect(
        computeCropSourceRect(
          cropRect: crop,
          hostWidth: 1080,
          hostHeight: 2400,
          imageWidth: 1080,
          imageHeight: 0,
        ),
        isNull,
      );
    });
  });
}
