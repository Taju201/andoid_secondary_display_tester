import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:andoid_secondary_display_tester/services/adb_parser.dart';

/// Trimmed from a real `dumpsys display` on a device with one Developer
/// Options simulated display (720x480 at 142dpi, exposed as display 2).
const _dumpsysWithOverlay = '''
DISPLAY MANAGER (dumpsys display)
  mOnlyCore=false
  mSafeMode=false
  mViewports=[DisplayViewport{type=INTERNAL, valid=true, isActive=true, displayId=0, uniqueId='local:0', physicalPort=0, orientation=0, logicalFrame=Rect(0, 0 - 1080, 2404), physicalFrame=Rect(0, 0 - 1080, 2404), deviceWidth=1080, deviceHeight=2404}, DisplayViewport{type=VIRTUAL, valid=true, isActive=true, displayId=2, uniqueId='overlay:1', physicalPort=null, orientation=0, logicalFrame=Rect(0, 0 - 720, 480), physicalFrame=Rect(0, 0 - 720, 480), deviceWidth=720, deviceHeight=480}]

  Display Adapters: size=3
    LocalDisplayAdapter
    OverlayDisplayAdapter
      mCurrentOverlaySetting=720x480/142
      mOverlays: size=1
        Overlay #1:
          mModes=[{width=720, height=480, densityDpi=142}]
          mActiveMode=0
          mGravity=51
          mFlags={secure=false, ownContentOnly=false, shouldShowSystemDecorations=false}
          mNumber=1
          mWindowVisible=true
          mWindowX=74
          mWindowY=381
          mWindowScale=1.0
          mWindowParams={(74,381)(720x480) gr=TOP LEFT CENTER ty=DISPLAY_OVERLAY alpha=0.8
            fl=NOT_FOCUSABLE NOT_TOUCH_MODAL LAYOUT_IN_SCREEN LAYOUT_NO_LIMITS HARDWARE_ACCELERATED
            pfl=FORCE_HARDWARE_ACCELERATED}
          mTextureView.getScaleX()=1.0
    WifiDisplayAdapter
      mFeatureOn=false

  Logical Displays: size=2
    Display 0:
      mDisplayId=0
      mBaseDisplayInfo=DisplayInfo{"Built-in Screen", displayId 0, real 1080 x 2404, uniqueId "local:0", density 440 (440.0 x 440.0) dpi, layerStack 0}
    Display 2:
      mDisplayId=2
      mBaseDisplayInfo=DisplayInfo{"Overlay #1", displayId 2, displayGroupId 0, FLAG_PRESENTATION, real 720 x 480, supportedModes [{id=3, width=720, height=480, fps=60.0}], rotation 0, state ON, type OVERLAY, uniqueId "overlay:1", app 720 x 480, density 142 (142.0 x 142.0) dpi, layerStack 2}
''';

void main() {
  group('parseOverlayDisplayIds', () {
    test('pairs each overlay uniqueId with the nearest preceding displayId',
        () {
      final ids = parseOverlayDisplayIds(_dumpsysWithOverlay);
      expect(ids, {1: 2});
    });

    test('does not pair across records on a shared line', () {
      // Both viewports live on one line; overlay:1 must bind to displayId=2,
      // not to the displayId=0 that appears first on the line.
      const line =
          "mViewports=[DisplayViewport{displayId=0, uniqueId='local:0'}, "
          "DisplayViewport{displayId=2, uniqueId='overlay:1'}]";
      expect(parseOverlayDisplayIds(line), {1: 2});
    });

    test('maps several overlays independently', () {
      const output = '''
        DisplayInfo{displayId 2, uniqueId "overlay:1"}
        DisplayInfo{displayId 5, uniqueId "overlay:3"}
      ''';
      expect(parseOverlayDisplayIds(output), {1: 2, 3: 5});
    });

    test('returns empty when there are no overlays', () {
      const output = 'DisplayInfo{displayId 0, uniqueId "local:0"}';
      expect(parseOverlayDisplayIds(output), isEmpty);
    });

    test('ignores mUniqueDisplayId lines that carry no displayId', () {
      const output = '  mUniqueDisplayId=overlay:1';
      expect(parseOverlayDisplayIds(output), isEmpty);
    });
  });

  group('parseOverlayWindows', () {
    test('parses window geometry, logical size and display id', () {
      final overlays = parseOverlayWindows(_dumpsysWithOverlay);

      expect(overlays, hasLength(1));
      final overlay = overlays.single;
      expect(overlay.number, 1);
      expect(overlay.displayId, 2);
      expect(overlay.windowRect, const Rect.fromLTWH(74, 381, 720, 480));
      expect(overlay.logicalWidth, 720);
      expect(overlay.logicalHeight, 480);
      expect(overlay.density, 142);
      expect(overlay.visible, isTrue);
      expect(overlay.uniqueId, 'overlay:1');
      expect(overlay.renderScale, 1.0);
    });

    test('reports the render scale when the window is smaller than the display',
        () {
      final output = _dumpsysWithOverlay.replaceAll(
        'mWindowParams={(74,381)(720x480)',
        'mWindowParams={(0,0)(360x240)',
      );

      final overlay = parseOverlayWindows(output).single;
      expect(overlay.windowRect, const Rect.fromLTWH(0, 0, 360, 240));
      expect(overlay.renderScale, 0.5);
    });

    test('carries the hidden state through', () {
      final output = _dumpsysWithOverlay.replaceAll(
        'mWindowVisible=true',
        'mWindowVisible=false',
      );
      expect(parseOverlayWindows(output).single.visible, isFalse);
    });

    test('parses negative window positions', () {
      final output = _dumpsysWithOverlay.replaceAll(
        'mWindowParams={(74,381)(720x480)',
        'mWindowParams={(-120,-40)(720x480)',
      );
      expect(
        parseOverlayWindows(output).single.windowRect,
        const Rect.fromLTWH(-120, -40, 720, 480),
      );
    });

    test('selects the mode named by mActiveMode', () {
      final output = _dumpsysWithOverlay
          .replaceAll(
            'mModes=[{width=720, height=480, densityDpi=142}]',
            'mModes=[{width=720, height=480, densityDpi=142}, '
                '{width=1280, height=720, densityDpi=213}]',
          )
          .replaceAll('mActiveMode=0', 'mActiveMode=1');

      final overlay = parseOverlayWindows(output).single;
      expect(overlay.logicalWidth, 1280);
      expect(overlay.logicalHeight, 720);
      expect(overlay.density, 213);
    });

    test('parses multiple overlays', () {
      final output = _dumpsysWithOverlay.replaceAll(
        '          mTextureView.getScaleX()=1.0\n',
        '''          mTextureView.getScaleX()=1.0
        Overlay #2:
          mModes=[{width=1280, height=720, densityDpi=213}]
          mActiveMode=0
          mNumber=2
          mWindowVisible=true
          mWindowParams={(10,20)(640x360) gr=TOP LEFT CENTER ty=DISPLAY_OVERLAY
''',
      );

      final overlays = parseOverlayWindows(output);
      expect(overlays.map((o) => o.number), [1, 2]);
      expect(overlays[1].windowRect, const Rect.fromLTWH(10, 20, 640, 360));
      expect(overlays[1].logicalWidth, 1280);
      // Overlay #2 has no uniqueId mapping in the fixture.
      expect(overlays[1].displayId, isNull);
    });

    test('returns empty when no simulated display is configured', () {
      const output = '''
  Display Adapters: size=3
    LocalDisplayAdapter
    OverlayDisplayAdapter
      mCurrentOverlaySetting=null
      mOverlays: size=0
    WifiDisplayAdapter
''';
      expect(parseOverlayWindows(output), isEmpty);
    });

    test('ignores overlay-shaped text outside the adapter section', () {
      const output = '''
  SomeOtherSection
        Overlay #9:
          mModes=[{width=100, height=100, densityDpi=160}]
          mWindowParams={(0,0)(100x100) gr=TOP LEFT
''';
      expect(parseOverlayWindows(output), isEmpty);
    });
  });
}
