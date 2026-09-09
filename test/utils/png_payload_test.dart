import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:andoid_secondary_display_tester/utils/png_payload.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('isPngData', () {
    test('accepts a PNG signature', () {
      expect(isPngData(_bytes([...pngSignature, 0x00, 0x01])), isTrue);
    });

    test('rejects the screencap failure message', () {
      // What `screencap -p -d <id>` writes to stdout — with exit code 0 — when
      // it cannot capture the requested display.
      final payload = _bytes(utf8.encode(
        'Failed to take screenshot. Status: -2\nCapturing failed.\n',
      ));
      expect(isPngData(payload), isFalse);
    });

    test('rejects empty output', () {
      expect(isPngData(_bytes([])), isFalse);
    });

    test('rejects output shorter than the signature', () {
      expect(isPngData(_bytes(pngSignature.take(4).toList())), isFalse);
    });

    test('rejects a JPEG signature', () {
      expect(isPngData(_bytes([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0])), isFalse);
    });
  });

  group('describeScreencapFailure', () {
    test('collapses the multi-line screencap error into one line', () {
      final payload = _bytes(utf8.encode(
        'Failed to take screenshot. Status: -2\nCapturing failed.\n',
      ));
      expect(
        describeScreencapFailure(payload),
        'Failed to take screenshot. Status: -2 Capturing failed.',
      );
    });

    test('reports empty output explicitly', () {
      expect(describeScreencapFailure(_bytes([])), 'screencap returned no data');
    });

    test('does not leak binary garbage into the message', () {
      final payload = _bytes([0x00, 0x01, 0x02, 0x03, 0xFE, 0xFF]);
      final message = describeScreencapFailure(payload);
      expect(message, 'screencap returned 6 bytes that are not a PNG');
    });

    test('truncates very long output', () {
      final payload = _bytes(utf8.encode('x' * 400));
      final message = describeScreencapFailure(payload);
      expect(message.length, lessThanOrEqualTo(201));
      expect(message, endsWith('…'));
    });
  });
}
