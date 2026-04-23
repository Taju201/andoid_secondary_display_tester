import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:andoid_secondary_display_tester/models/touch_action.dart';
import 'package:andoid_secondary_display_tester/models/recording.dart';

void main() {
  group('TouchAction', () {
    test('tap serialization round-trip', () {
      const action = TouchAction(
        type: TouchActionType.tap,
        x: 540,
        y: 1170,
        timestampMs: 100,
      );

      final json = action.toJson();
      final restored = TouchAction.fromJson(json);

      expect(restored.type, TouchActionType.tap);
      expect(restored.x, 540);
      expect(restored.y, 1170);
      expect(restored.endX, isNull);
      expect(restored.endY, isNull);
      expect(restored.durationMs, isNull);
      expect(restored.timestampMs, 100);
    });

    test('swipe serialization round-trip', () {
      const action = TouchAction(
        type: TouchActionType.swipe,
        x: 100,
        y: 200,
        endX: 400,
        endY: 600,
        durationMs: 300,
        timestampMs: 500,
      );

      final json = action.toJson();
      final restored = TouchAction.fromJson(json);

      expect(restored.type, TouchActionType.swipe);
      expect(restored.x, 100);
      expect(restored.y, 200);
      expect(restored.endX, 400);
      expect(restored.endY, 600);
      expect(restored.durationMs, 300);
      expect(restored.timestampMs, 500);
    });

    test('longPress serialization round-trip', () {
      const action = TouchAction(
        type: TouchActionType.longPress,
        x: 300,
        y: 400,
        durationMs: 1000,
        timestampMs: 2000,
      );

      final json = action.toJson();
      final restored = TouchAction.fromJson(json);

      expect(restored.type, TouchActionType.longPress);
      expect(restored.durationMs, 1000);
    });

    test('summary formatting', () {
      const tap = TouchAction(type: TouchActionType.tap, x: 120, y: 45, timestampMs: 0);
      expect(tap.summary, 'tap(120, 45)');

      const swipe = TouchAction(
        type: TouchActionType.swipe, x: 100, y: 200,
        endX: 400, endY: 600, durationMs: 300, timestampMs: 0,
      );
      expect(swipe.summary, contains('swipe'));
    });
  });

  group('Recording', () {
    test('serialization round-trip', () {
      final recording = Recording(
        name: 'Test Recording',
        createdAt: DateTime(2024, 1, 15, 10, 30),
        displayId: 2,
        displayWidth: 800,
        displayHeight: 600,
        actions: const [
          TouchAction(type: TouchActionType.tap, x: 100, y: 200, timestampMs: 0),
          TouchAction(type: TouchActionType.swipe, x: 100, y: 200, endX: 300, endY: 400, durationMs: 300, timestampMs: 500),
          TouchAction(type: TouchActionType.longPress, x: 400, y: 300, durationMs: 1000, timestampMs: 1500),
        ],
      );

      final jsonStr = jsonEncode(recording.toJson());
      final restored = Recording.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(restored.name, 'Test Recording');
      expect(restored.displayId, 2);
      expect(restored.displayWidth, 800);
      expect(restored.displayHeight, 600);
      expect(restored.actionCount, 3);
      expect(restored.actions[0].type, TouchActionType.tap);
      expect(restored.actions[1].type, TouchActionType.swipe);
      expect(restored.actions[2].type, TouchActionType.longPress);
    });

    test('totalDurationMs returns last action timestamp', () {
      final recording = Recording(
        name: 'Test',
        createdAt: DateTime.now(),
        displayId: 0,
        displayWidth: 1080,
        displayHeight: 1920,
        actions: const [
          TouchAction(type: TouchActionType.tap, x: 0, y: 0, timestampMs: 0),
          TouchAction(type: TouchActionType.tap, x: 0, y: 0, timestampMs: 5000),
        ],
      );
      expect(recording.totalDurationMs, 5000);
    });

    test('empty recording has zero duration', () {
      final recording = Recording(
        name: 'Empty',
        createdAt: DateTime.now(),
        displayId: 0,
        displayWidth: 100,
        displayHeight: 100,
      );
      expect(recording.totalDurationMs, 0);
      expect(recording.actionCount, 0);
    });
  });
}
