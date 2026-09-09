import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:andoid_secondary_display_tester/controllers/display_mirror_controller.dart';
import 'package:andoid_secondary_display_tester/models/overlay_window.dart';
import 'package:andoid_secondary_display_tester/services/adb_service.dart';

/// An [AdbService] that never shells out — it replays whatever the test says
/// `screencap` would return for each display.
class _FakeAdb extends AdbService {
  /// Display id -> what capturing it produces. A [ScreencapException] value is
  /// thrown instead of returned.
  final Map<int, Object> responses;

  final captured = <int>[];

  _FakeAdb(this.responses);

  @override
  Future<Uint8List> captureScreenshot(String serial, int displayId) async {
    captured.add(displayId);
    final response = responses[displayId];
    if (response is Uint8List) return response;
    if (response is Object) throw response;
    throw ScreencapException(displayId: displayId, reason: 'no such display');
  }
}

/// Build a real PNG so the crop path exercises actual decoding.
Future<Uint8List> _solidPng(int width, int height) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData(format: ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

OverlayCaptureSource _source({
  Rect crop = const Rect.fromLTWH(74, 381, 720, 480),
  int hostWidth = 1080,
  int hostHeight = 2404,
}) {
  return OverlayCaptureSource(
    hostDisplayId: 0,
    hostWidth: hostWidth,
    hostHeight: hostHeight,
    cropRect: crop,
    overlay: OverlayWindow(
      number: 1,
      displayId: 2,
      windowRect: crop,
      logicalWidth: 720,
      logicalHeight: 480,
      density: 142,
      visible: true,
    ),
  );
}

/// Wait until [condition] holds, so tests do not depend on how many capture
/// ticks the controller needs.
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List hostPng;

  setUpAll(() async {
    hostPng = await _solidPng(1080, 2404);
  });

  test('mirrors directly when the display captures on its own', () async {
    final displayPng = await _solidPng(720, 480);
    final adb = _FakeAdb({2: displayPng});
    final controller = DisplayMirrorController(adb)
      ..captureInterval.value = const Duration(milliseconds: 10);

    var resolverCalls = 0;
    controller.startCapture('serial', 2, overlayResolver: () async {
      resolverCalls++;
      return _source();
    });

    await _waitFor(() => controller.currentFrame.value != null);

    expect(controller.mode.value, MirrorMode.direct);
    expect(controller.fallbackReason.value, isNull);
    expect(controller.error.value, isNull);
    expect(adb.captured, everyElement(2));
    expect(resolverCalls, 0,
        reason: 'the overlay resolver should stay untouched on the happy path');

    controller.dispose();
  });

  test('falls back to cropping the host display when screencap refuses',
      () async {
    final adb = _FakeAdb({
      0: hostPng,
      2: ScreencapException(
        displayId: 2,
        reason: 'Failed to take screenshot. Status: -2 Capturing failed.',
      ),
    });
    final controller = DisplayMirrorController(adb)
      ..captureInterval.value = const Duration(milliseconds: 10);

    controller.startCapture(
      'serial',
      2,
      overlayResolver: () async => _source(),
    );

    await _waitFor(() => controller.currentFrame.value != null);

    expect(controller.mode.value, MirrorMode.overlayCrop);
    expect(
      controller.fallbackReason.value,
      'Failed to take screenshot. Status: -2 Capturing failed.',
    );
    expect(controller.error.value, isNull,
        reason: 'a handled fallback is not an error the user needs to see');
    expect(controller.overlaySource.value?.hostDisplayId, 0);
    expect(adb.captured, contains(0));

    // The published frame is the cropped overlay region, not the host display.
    final codec = await instantiateImageCodec(controller.currentFrame.value!);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 720);
    expect(frame.image.height, 480);
    frame.image.dispose();
    codec.dispose();

    controller.dispose();
  });

  test('reports the error when there is no overlay to fall back to', () async {
    final adb = _FakeAdb({
      2: ScreencapException(displayId: 2, reason: 'Capturing failed.'),
    });
    final controller = DisplayMirrorController(adb)
      ..captureInterval.value = const Duration(milliseconds: 10);

    controller.startCapture('serial', 2, overlayResolver: () async => null);

    await _waitFor(() => controller.error.value != null);

    expect(controller.mode.value, MirrorMode.direct);
    expect(controller.currentFrame.value, isNull);
    expect(controller.error.value, contains('Capturing failed.'));

    controller.dispose();
  });

  test('stops the loop after repeated failures with no fallback available',
      () async {
    final adb = _FakeAdb({
      2: ScreencapException(displayId: 2, reason: 'Capturing failed.'),
    });
    final controller = DisplayMirrorController(adb)
      ..captureInterval.value = const Duration(milliseconds: 5);

    controller.startCapture('serial', 2);

    await _waitFor(() => !controller.isCapturing.value);

    expect(controller.error.value, contains('Capture stopped after'));

    controller.dispose();
  });

  test('only probes the fallback once per capture session', () async {
    // Both the display and its host refuse — the loop must not re-run the
    // resolver on every tick after it has already committed to crop mode.
    final adb = _FakeAdb({
      0: ScreencapException(displayId: 0, reason: 'Capturing failed.'),
      2: ScreencapException(displayId: 2, reason: 'Capturing failed.'),
    });
    final controller = DisplayMirrorController(adb)
      ..captureInterval.value = const Duration(milliseconds: 5)
      ..overlayRefreshInterval.value = const Duration(hours: 1);

    var resolverCalls = 0;
    controller.startCapture('serial', 2, overlayResolver: () async {
      resolverCalls++;
      return _source();
    });

    await _waitFor(() => !controller.isCapturing.value);

    expect(controller.error.value, contains('Capture stopped after'));
    expect(resolverCalls, 1);

    controller.dispose();
  });

  test('re-reads the overlay geometry so a moved window keeps mirroring',
      () async {
    final adb = _FakeAdb({0: hostPng});
    final controller = DisplayMirrorController(adb)
      ..captureInterval.value = const Duration(milliseconds: 10)
      ..overlayRefreshInterval.value = Duration.zero;

    adb.responses[2] = ScreencapException(
      displayId: 2,
      reason: 'Capturing failed.',
    );

    var crop = const Rect.fromLTWH(0, 0, 720, 480);
    controller.startCapture(
      'serial',
      2,
      overlayResolver: () async => _source(crop: crop),
    );

    await _waitFor(() => controller.mode.value == MirrorMode.overlayCrop);
    await _waitFor(() => controller.currentFrame.value != null);

    // The user drags the overlay somewhere else.
    crop = const Rect.fromLTWH(200, 900, 360, 240);

    await _waitFor(
      () => controller.overlaySource.value?.cropRect.left == 200,
    );

    // Wait for a frame captured *after* the move, not the one still on screen.
    final stale = controller.currentFrame.value;
    await _waitFor(() => !identical(controller.currentFrame.value, stale));

    final codec = await instantiateImageCodec(controller.currentFrame.value!);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 360);
    expect(frame.image.height, 240);
    frame.image.dispose();
    codec.dispose();

    controller.dispose();
  });
}
