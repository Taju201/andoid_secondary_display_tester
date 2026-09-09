import 'dart:ui';

import '../models/device.dart';
import '../models/display_info.dart';
import '../models/overlay_window.dart';

/// Parse the output of `adb devices -l` into a list of [AdbDevice].
///
/// Example input:
/// ```
/// List of devices attached
/// emulator-5554          device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa transport_id:1
/// 192.168.1.100:5555     device product:raven model:Pixel_6_Pro device:raven transport_id:3
/// ```
List<AdbDevice> parseDeviceList(String output) {
  final lines = output.split('\n');
  final devices = <AdbDevice>[];

  for (final line in lines) {
    final trimmed = line.trim();

    // Skip header line and empty lines
    if (trimmed.isEmpty || trimmed.startsWith('List of devices')) {
      continue;
    }

    // Skip lines that don't look like device entries
    if (!trimmed.contains('\t') && !RegExp(r'\s{2,}').hasMatch(trimmed)) {
      continue;
    }

    try {
      devices.add(AdbDevice.fromDevicesLine(trimmed));
    } catch (_) {
      // Skip unparseable lines
    }
  }

  return devices;
}

/// Parse `dumpsys display` output to extract available displays.
///
/// Looks for display info blocks like:
/// ```
/// Display Devices: ...
///   mDisplayId=0
///   mDisplayId=2
/// ```
///
/// And physical display info like:
/// ```
///   DisplayDeviceInfo{...: ..., 1080 x 2340, ...density 420, ...}
/// ```
List<DisplayInfo> parseDisplays(String dumpsysOutput) {
  final displays = <int, DisplayInfo>{};

  // Pattern 1: Look for "mDisplayId=N" with associated size info
  // This parses the "Display #N" blocks from dumpsys display
  final displayBlockRegex = RegExp(
    r'Display (\d+) info=DisplayInfo\{[^}]*'
    r'(?:real\s+|, )(\d+)\s*x\s*(\d+)'
    r'[^}]*?density\s+(\d+)',
    multiLine: true,
  );

  for (final match in displayBlockRegex.allMatches(dumpsysOutput)) {
    final id = int.parse(match.group(1)!);
    final width = int.parse(match.group(2)!);
    final height = int.parse(match.group(3)!);
    final density = int.parse(match.group(4)!);

    displays[id] = DisplayInfo(
      id: id,
      name: 'Display $id',
      width: width,
      height: height,
      density: density,
    );
  }

  // Pattern 2: Fallback — look for "mDisplayId=N" lines and associate
  // with nearby size information
  if (displays.isEmpty) {
    final lines = dumpsysOutput.split('\n');
    int? currentDisplayId;
    String currentName = '';

    for (final line in lines) {
      final trimmed = line.trim();

      // Match "mDisplayId=N"
      final displayIdMatch =
          RegExp(r'mDisplayId=(\d+)').firstMatch(trimmed);
      if (displayIdMatch != null) {
        currentDisplayId = int.parse(displayIdMatch.group(1)!);
        currentName = 'Display $currentDisplayId';
      }

      // Match display name
      final nameMatch =
          RegExp(r'mName=(.+?)(?:,|\s*$)').firstMatch(trimmed);
      if (nameMatch != null && currentDisplayId != null) {
        currentName = nameMatch.group(1)!.trim();
      }

      // Match size like "1080 x 2340" or "1080x2340"
      if (currentDisplayId != null && !displays.containsKey(currentDisplayId)) {
        final sizeMatch =
            RegExp(r'(\d{3,5})\s*x\s*(\d{3,5})').firstMatch(trimmed);
        final densityMatch =
            RegExp(r'density[=:\s]+(\d+)').firstMatch(trimmed);

        if (sizeMatch != null) {
          displays[currentDisplayId] = DisplayInfo(
            id: currentDisplayId,
            name: currentName,
            width: int.parse(sizeMatch.group(1)!),
            height: int.parse(sizeMatch.group(2)!),
            density: densityMatch != null
                ? int.parse(densityMatch.group(1)!)
                : 160,
          );
        }
      }
    }
  }

  // Sort by display ID
  final sorted = displays.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  return sorted;
}

/// Extract the version string from `adb version` output.
///
/// Example input:
/// ```
/// Android Debug Bridge version 1.0.41
/// Version 34.0.5-10900879
/// ```
///
/// Returns: "1.0.41"
String parseAdbVersion(String output) {
  final match = RegExp(r'version\s+([\d.]+)').firstMatch(output);
  return match?.group(1) ?? 'unknown';
}

/// Parse the `OverlayDisplayAdapter` section of `dumpsys display` into the set
/// of Developer Options simulated displays and where their windows sit on the
/// host display.
///
/// Example input:
/// ```
///   OverlayDisplayAdapter
///     mCurrentOverlaySetting=720x480/142
///     mOverlays: size=1
///       Overlay #1:
///         mModes=[{width=720, height=480, densityDpi=142}]
///         mActiveMode=0
///         mNumber=1
///         mWindowVisible=true
///         mWindowParams={(74,381)(720x480) gr=TOP LEFT CENTER ty=DISPLAY_OVERLAY
/// ```
///
/// The logical display id (e.g. `2`) is not printed inside the overlay block,
/// so it is recovered separately by matching `overlay:<number>` against the
/// `uniqueId` fields elsewhere in the dump — see [parseOverlayDisplayIds].
List<OverlayWindow> parseOverlayWindows(String dumpsysOutput) {
  final displayIds = parseOverlayDisplayIds(dumpsysOutput);
  final overlays = <OverlayWindow>[];

  int? number;
  Rect? windowRect;
  var visible = true;
  var activeMode = 0;
  var modes = <List<int>>[];

  void flush() {
    if (number == null || windowRect == null || modes.isEmpty) return;
    final mode = modes[activeMode.clamp(0, modes.length - 1)];
    overlays.add(OverlayWindow(
      number: number!,
      displayId: displayIds[number!],
      windowRect: windowRect,
      logicalWidth: mode[0],
      logicalHeight: mode[1],
      density: mode[2],
      visible: visible,
    ));
    number = null;
  }

  // The adapter section is delimited by indentation: it runs from the
  // `OverlayDisplayAdapter` header until the next line indented no deeper than
  // that header. Matching on content instead would end the section early —
  // `mWindowParams` spills onto continuation lines that look nothing like the
  // fields around them.
  int? adapterIndent;

  for (final line in dumpsysOutput.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final indent = line.length - line.trimLeft().length;

    if (adapterIndent == null) {
      if (trimmed == 'OverlayDisplayAdapter') adapterIndent = indent;
      continue;
    }

    if (indent <= adapterIndent) {
      flush();
      adapterIndent = trimmed == 'OverlayDisplayAdapter' ? indent : null;
      continue;
    }

    final header = RegExp(r'^Overlay #(\d+):').firstMatch(trimmed);
    if (header != null) {
      flush();
      number = int.parse(header.group(1)!);
      windowRect = null;
      visible = true;
      activeMode = 0;
      modes = <List<int>>[];
      continue;
    }
    if (number == null) continue;

    final modesMatch = RegExp(r'^mModes=\[(.*)\]$').firstMatch(trimmed);
    if (modesMatch != null) {
      final modeRegex =
          RegExp(r'width=(\d+),\s*height=(\d+),\s*densityDpi=(\d+)');
      modes = [
        for (final m in modeRegex.allMatches(modesMatch.group(1)!))
          [
            int.parse(m.group(1)!),
            int.parse(m.group(2)!),
            int.parse(m.group(3)!),
          ],
      ];
      continue;
    }

    final activeModeMatch = RegExp(r'^mActiveMode=(\d+)$').firstMatch(trimmed);
    if (activeModeMatch != null) {
      activeMode = int.parse(activeModeMatch.group(1)!);
      continue;
    }

    final visibleMatch =
        RegExp(r'^mWindowVisible=(true|false)$').firstMatch(trimmed);
    if (visibleMatch != null) {
      visible = visibleMatch.group(1) == 'true';
      continue;
    }

    // mWindowParams={(74,381)(720x480) gr=TOP LEFT CENTER ...
    final paramsMatch = RegExp(
      r'^mWindowParams=\{\((-?\d+),(-?\d+)\)\((\d+)x(\d+)\)',
    ).firstMatch(trimmed);
    if (paramsMatch != null) {
      windowRect = Rect.fromLTWH(
        double.parse(paramsMatch.group(1)!),
        double.parse(paramsMatch.group(2)!),
        double.parse(paramsMatch.group(3)!),
        double.parse(paramsMatch.group(4)!),
      );
      continue;
    }
  }

  flush();
  return overlays;
}

/// Map `overlay:<number>` unique ids to the logical display ids they were
/// assigned, by scanning every line that carries both.
///
/// `dumpsys display` prints the pairing in a few places, e.g.
/// `DisplayInfo{"Overlay #1", displayId 2, ... uniqueId "overlay:1", ...}` and
/// `DisplayViewport{... displayId=2, uniqueId='overlay:1' ...}`. A single line
/// can hold several such records, so each `uniqueId` is paired with the
/// closest `displayId` that precedes it rather than the first one on the line.
Map<int, int> parseOverlayDisplayIds(String dumpsysOutput) {
  final result = <int, int>{};
  final displayIdRegex = RegExp(r'displayId[=\s]+(\d+)');
  final uniqueIdRegex = RegExp(r"""uniqueId[=:\s]+['"]?overlay:(\d+)""");

  for (final line in dumpsysOutput.split('\n')) {
    final displayIdMatches = displayIdRegex.allMatches(line).toList();
    if (displayIdMatches.isEmpty) continue;

    for (final unique in uniqueIdRegex.allMatches(line)) {
      RegExpMatch? nearest;
      for (final candidate in displayIdMatches) {
        if (candidate.start < unique.start) {
          nearest = candidate;
        } else {
          break;
        }
      }
      if (nearest == null) continue;

      final overlayNumber = int.parse(unique.group(1)!);
      result.putIfAbsent(overlayNumber, () => int.parse(nearest!.group(1)!));
    }
  }

  return result;
}
