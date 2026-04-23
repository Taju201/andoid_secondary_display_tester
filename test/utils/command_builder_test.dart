import 'package:flutter_test/flutter_test.dart';

import 'package:andoid_secondary_display_tester/utils/command_builder.dart';

void main() {
  group('buildTapCommand', () {
    test('formats tap command correctly', () {
      expect(
        buildTapCommand(2, 540.0, 1170.0),
        'input -d 2 tap 540 1170',
      );
    });

    test('rounds fractional coordinates', () {
      expect(
        buildTapCommand(0, 100.7, 200.3),
        'input -d 0 tap 101 200',
      );
    });

    test('handles zero coordinates', () {
      expect(
        buildTapCommand(1, 0.0, 0.0),
        'input -d 1 tap 0 0',
      );
    });
  });

  group('buildSwipeCommand', () {
    test('formats swipe command correctly', () {
      expect(
        buildSwipeCommand(2, 100.0, 200.0, 400.0, 600.0, 300),
        'input -d 2 swipe 100 200 400 600 300',
      );
    });

    test('rounds fractional coordinates', () {
      expect(
        buildSwipeCommand(0, 10.4, 20.6, 30.5, 40.1, 500),
        'input -d 0 swipe 10 21 31 40 500',
      );
    });
  });

  group('buildLongPressCommand', () {
    test('generates swipe with same start and end', () {
      final cmd = buildLongPressCommand(2, 540.0, 1170.0, 1000);
      expect(cmd, 'input -d 2 swipe 540 1170 540 1170 1000');
    });
  });
}
