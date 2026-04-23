import '../models/device.dart';
import '../models/display_info.dart';

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
