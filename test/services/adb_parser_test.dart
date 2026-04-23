import 'package:flutter_test/flutter_test.dart';

import 'package:andoid_secondary_display_tester/services/adb_parser.dart';

void main() {
  group('parseDeviceList', () {
    test('parses single device with all properties', () {
      const output = '''List of devices attached
emulator-5554          device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa transport_id:1

''';
      final devices = parseDeviceList(output);
      expect(devices, hasLength(1));
      expect(devices[0].serial, 'emulator-5554');
      expect(devices[0].state, 'device');
      expect(devices[0].model, 'sdk_gphone64_x86_64');
      expect(devices[0].product, 'sdk_gphone64_x86_64');
      expect(devices[0].device, 'emu64xa');
      expect(devices[0].transportId, '1');
      expect(devices[0].isOnline, isTrue);
    });

    test('parses multiple devices', () {
      const output = '''List of devices attached
emulator-5554          device product:sdk model:Pixel device:emu transport_id:1
192.168.1.100:5555     device product:raven model:Pixel_6_Pro device:raven transport_id:3

''';
      final devices = parseDeviceList(output);
      expect(devices, hasLength(2));
      expect(devices[0].serial, 'emulator-5554');
      expect(devices[1].serial, '192.168.1.100:5555');
      expect(devices[1].model, 'Pixel_6_Pro');
    });

    test('returns empty list for no devices', () {
      const output = '''List of devices attached

''';
      final devices = parseDeviceList(output);
      expect(devices, isEmpty);
    });

    test('parses unauthorized device', () {
      const output = '''List of devices attached
ABCDEF123456           unauthorized transport_id:2

''';
      final devices = parseDeviceList(output);
      expect(devices, hasLength(1));
      expect(devices[0].serial, 'ABCDEF123456');
      expect(devices[0].state, 'unauthorized');
      expect(devices[0].isOnline, isFalse);
      expect(devices[0].isUnauthorized, isTrue);
    });

    test('parses offline device', () {
      const output = '''List of devices attached
emulator-5554          offline

''';
      final devices = parseDeviceList(output);
      expect(devices, hasLength(1));
      expect(devices[0].state, 'offline');
      expect(devices[0].isOnline, isFalse);
    });
  });

  group('parseDisplays', () {
    test('parses display info from dumpsys output', () {
      const output = '''
Display 0 info=DisplayInfo{"Built-in Screen", displayId 0, real 1080 x 2340, density 420, some other info}
Display 2 info=DisplayInfo{"Secondary", displayId 2, real 800 x 600, density 160, some other info}
''';
      final displays = parseDisplays(output);
      expect(displays, hasLength(2));
      expect(displays[0].id, 0);
      expect(displays[0].width, 1080);
      expect(displays[0].height, 2340);
      expect(displays[0].density, 420);
      expect(displays[1].id, 2);
      expect(displays[1].width, 800);
      expect(displays[1].height, 600);
      expect(displays[1].density, 160);
    });

    test('returns empty list for no displays', () {
      const output = 'Some random dumpsys output with no display info';
      final displays = parseDisplays(output);
      expect(displays, isEmpty);
    });

    test('displays are sorted by ID', () {
      const output = '''
Display 3 info=DisplayInfo{"Third", displayId 3, real 640 x 480, density 160, info}
Display 0 info=DisplayInfo{"Primary", displayId 0, real 1080 x 2340, density 420, info}
''';
      final displays = parseDisplays(output);
      expect(displays[0].id, 0);
      expect(displays[1].id, 3);
    });
  });

  group('parseAdbVersion', () {
    test('extracts version from standard output', () {
      const output = '''Android Debug Bridge version 1.0.41
Version 34.0.5-10900879
Installed as /usr/bin/adb''';
      expect(parseAdbVersion(output), '1.0.41');
    });

    test('returns unknown for unrecognized output', () {
      expect(parseAdbVersion('no version here'), 'unknown');
    });
  });
}
