import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../utils/png_payload.dart';

/// Service for running ADB commands and interacting with Android devices.
///
/// All ADB commands are executed through this service, making it the single
/// point of contact with the `adb` executable. This design keeps command
/// construction and process execution separate from UI and parsing logic.
class AdbService {
  /// Current ADB executable path.
  String adbPath;

  AdbService({this.adbPath = 'adb'});

  /// Validate that the ADB executable exists and is runnable.
  Future<bool> validate() async {
    try {
      final result = await runCommand(['version']);
      return result.contains('Android Debug Bridge');
    } catch (_) {
      return false;
    }
  }

  /// Get the ADB version string.
  Future<String> version() async {
    return runCommand(['version']);
  }

  /// Run a generic ADB command and return stdout.
  ///
  /// Throws [AdbException] if the command fails (non-zero exit code).
  Future<String> runCommand(List<String> args) async {
    final result = await Process.run(adbPath, args);
    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      throw AdbException(
        command: '$adbPath ${args.join(' ')}',
        exitCode: result.exitCode,
        stderr: stderr.isNotEmpty ? stderr : (result.stdout as String).trim(),
      );
    }
    return (result.stdout as String);
  }

  /// Run `adb devices -l` and return the raw output.
  Future<String> devices() async {
    return runCommand(['devices', '-l']);
  }

  /// Run a shell command on a specific device.
  Future<String> shell(String serial, String command) async {
    return runCommand(['-s', serial, 'shell', command]);
  }

  /// Run `exec-out` and return raw binary output (for screenshots).
  Future<Uint8List> execOutBytes(
    String serial,
    List<String> args,
  ) async {
    final process = await Process.start(
      adbPath,
      ['-s', serial, 'exec-out', ...args],
    );

    final chunks = <List<int>>[];
    await for (final chunk in process.stdout) {
      chunks.add(chunk);
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final stderr = await process.stderr.transform(utf8.decoder).join();
      throw AdbException(
        command: '$adbPath -s $serial exec-out ${args.join(' ')}',
        exitCode: exitCode,
        stderr: stderr,
      );
    }

    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return result;
  }

  /// Get dumpsys display information for a device.
  Future<String> dumpsysDisplay(String serial) async {
    return shell(serial, 'dumpsys display');
  }

  /// Capture a screenshot for a specific display.
  ///
  /// Returns raw PNG bytes from `screencap -p -d <displayId>`.
  ///
  /// Throws [ScreencapException] when the device accepts the command but
  /// declines to capture the display. `screencap` signals that failure by
  /// exiting 0 and writing a plain-text message to stdout, so a non-zero exit
  /// code is not enough to detect it — the payload has to be checked for a PNG
  /// signature or the error text ends up being handed to the image decoder.
  Future<Uint8List> captureScreenshot(String serial, int displayId) async {
    final bytes =
        await execOutBytes(serial, ['screencap', '-p', '-d', '$displayId']);

    if (!isPngData(bytes)) {
      throw ScreencapException(
        displayId: displayId,
        reason: describeScreencapFailure(bytes),
      );
    }

    return bytes;
  }

  /// Send a tap input to a specific display.
  Future<void> inputTap(
    String serial,
    int displayId,
    double x,
    double y,
  ) async {
    await shell(
      serial,
      'input -d $displayId tap ${x.round()} ${y.round()}',
    );
  }

  /// Send a swipe input to a specific display.
  Future<void> inputSwipe(
    String serial,
    int displayId,
    double x1,
    double y1,
    double x2,
    double y2,
    int durationMs,
  ) async {
    await shell(
      serial,
      'input -d $displayId swipe '
      '${x1.round()} ${y1.round()} '
      '${x2.round()} ${y2.round()} '
      '$durationMs',
    );
  }

  /// Send a long-press input to a specific display.
  ///
  /// Implemented as a zero-distance swipe with the given duration.
  Future<void> inputLongPress(
    String serial,
    int displayId,
    double x,
    double y,
    int durationMs,
  ) async {
    await inputSwipe(serial, displayId, x, y, x, y, durationMs);
  }
}

/// Exception thrown when an ADB command fails.
class AdbException implements Exception {
  final String command;
  final int exitCode;
  final String stderr;

  const AdbException({
    required this.command,
    required this.exitCode,
    required this.stderr,
  });

  @override
  String toString() =>
      'AdbException: Command "$command" failed (exit $exitCode): $stderr';
}

/// Thrown when `screencap` runs successfully but refuses to capture a display.
///
/// This is the expected failure for Developer Options simulated displays:
/// `screencap -d` addresses SurfaceFlinger displays, and a simulated display is
/// only a window composited onto the host display, so it has no SurfaceFlinger
/// display of its own to capture.
class ScreencapException implements Exception {
  final int displayId;
  final String reason;

  const ScreencapException({required this.displayId, required this.reason});

  @override
  String toString() => 'Display $displayId cannot be captured directly: $reason';
}
