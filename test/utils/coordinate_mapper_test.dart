import 'package:flutter_test/flutter_test.dart';

import 'package:andoid_secondary_display_tester/utils/coordinate_mapper.dart';

void main() {
  group('CoordinateMapper', () {
    test('exact fit — no letterboxing', () {
      final mapper = CoordinateMapper(
        displayWidth: 1080,
        displayHeight: 1920,
        viewWidth: 1080,
        viewHeight: 1920,
      );

      expect(mapper.scale, 1.0);
      expect(mapper.imageOffset, Offset.zero);

      // Center point maps directly
      final result = mapper.mapToDisplay(const Offset(540, 960));
      expect(result, isNotNull);
      expect(result!.dx, closeTo(540, 0.1));
      expect(result.dy, closeTo(960, 0.1));
    });

    test('wider view — vertical letterboxing (horizontal bars)', () {
      // Display is 1080x1920 (tall), view is 1000x1000 (square)
      // Scale = min(1000/1080, 1000/1920) = min(0.926, 0.521) = 0.521
      final mapper = CoordinateMapper(
        displayWidth: 1080,
        displayHeight: 1920,
        viewWidth: 1000,
        viewHeight: 1000,
      );

      expect(mapper.scale, closeTo(0.5208, 0.001));
      // Image width = 1080 * 0.5208 = 562.5
      // Horizontal offset = (1000 - 562.5) / 2 = 218.75
      expect(mapper.imageOffset.dx, greaterThan(0));
      expect(mapper.imageOffset.dy, closeTo(0, 0.1));
    });

    test('taller view — horizontal letterboxing (vertical bars)', () {
      // Display is 1920x1080 (wide), view is 1000x1000 (square)
      final mapper = CoordinateMapper(
        displayWidth: 1920,
        displayHeight: 1080,
        viewWidth: 1000,
        viewHeight: 1000,
      );

      expect(mapper.imageOffset.dx, closeTo(0, 0.1));
      expect(mapper.imageOffset.dy, greaterThan(0));
    });

    test('center point maps correctly with scaling', () {
      final mapper = CoordinateMapper(
        displayWidth: 800,
        displayHeight: 600,
        viewWidth: 400,
        viewHeight: 300,
      );

      // Scale = 0.5, no letterboxing (aspect ratio matches)
      final result = mapper.mapToDisplay(const Offset(200, 150));
      expect(result, isNotNull);
      expect(result!.dx, closeTo(400, 0.1)); // center of 800
      expect(result.dy, closeTo(300, 0.1)); // center of 600
    });

    test('letterbox region returns null', () {
      final mapper = CoordinateMapper(
        displayWidth: 1080,
        displayHeight: 1920,
        viewWidth: 1000,
        viewHeight: 1000,
      );

      // Point in the left letterbox
      final result = mapper.mapToDisplay(const Offset(0, 500));
      expect(result, isNull);

      // Point in the right letterbox
      final result2 = mapper.mapToDisplay(
        Offset(mapper.imageOffset.dx + mapper.imageSize.width + 10, 500),
      );
      expect(result2, isNull);
    });

    test('inverse mapping round-trip', () {
      final mapper = CoordinateMapper(
        displayWidth: 1080,
        displayHeight: 1920,
        viewWidth: 800,
        viewHeight: 600,
      );

      const displayPoint = Offset(540, 960);
      final viewPoint = mapper.mapToView(displayPoint);
      final roundTrip = mapper.mapToDisplay(viewPoint);

      expect(roundTrip, isNotNull);
      expect(roundTrip!.dx, closeTo(displayPoint.dx, 0.1));
      expect(roundTrip.dy, closeTo(displayPoint.dy, 0.1));
    });

    test('corners map correctly', () {
      final mapper = CoordinateMapper(
        displayWidth: 1000,
        displayHeight: 500,
        viewWidth: 500,
        viewHeight: 500,
      );

      // Scale = min(500/1000, 500/500) = 0.5
      // Image size = 500x250, offset = (0, 125)

      // Top-left of display image
      final topLeft = mapper.mapToDisplay(Offset(0, mapper.imageOffset.dy));
      expect(topLeft, isNotNull);
      expect(topLeft!.dx, closeTo(0, 0.1));
      expect(topLeft.dy, closeTo(0, 0.1));

      // Bottom-right of display image
      final bottomRight = mapper.mapToDisplay(
        Offset(
          mapper.imageSize.width,
          mapper.imageOffset.dy + mapper.imageSize.height,
        ),
      );
      expect(bottomRight, isNotNull);
      expect(bottomRight!.dx, closeTo(1000, 1));
      expect(bottomRight.dy, closeTo(500, 1));
    });
  });
}
