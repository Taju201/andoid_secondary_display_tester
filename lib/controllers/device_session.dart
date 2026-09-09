import 'package:signals/signals.dart';

import '../models/device.dart';
import '../models/display_info.dart';
import '../models/overlay_window.dart';
import '../services/adb_parser.dart';
import '../services/adb_service.dart';

/// Manages the ADB connection state, connected devices, and display selection.
///
/// Uses [Signal] for fine-grained reactivity. UI widgets use [Watch] or
/// `.watch(context)` to rebuild only when the specific signal they depend on
/// changes.
class DeviceSession {
  final AdbService _adb;

  DeviceSession(this._adb);

  // ── Signals ──────────────────────────────────────────────────────────────

  /// Whether ADB has been validated as runnable.
  final adbValid = signal<bool>(false);

  /// The ADB version string (e.g., "1.0.41").
  final adbVersion = signal<String>('');

  /// List of connected Android devices.
  final devices = signal<List<AdbDevice>>([]);

  /// The currently selected device (null if none selected).
  final selectedDevice = signal<AdbDevice?>(null);

  /// List of displays available on the selected device.
  final displays = signal<List<DisplayInfo>>([]);

  /// Simulated (Developer Options) overlay displays on the selected device.
  final overlayWindows = signal<List<OverlayWindow>>([]);

  /// The currently selected display (null if none selected).
  final selectedDisplay = signal<DisplayInfo?>(null);

  /// Whether a background operation is in progress.
  final isLoading = signal<bool>(false);

  /// The last error message, or null if no error.
  final error = signal<String?>(null);

  // ── Computed ─────────────────────────────────────────────────────────────

  /// Whether a device is currently selected and online.
  late final hasDevice = computed(
    () => selectedDevice.value != null && selectedDevice.value!.isOnline,
  );

  /// Whether a display is currently selected.
  late final hasDisplay = computed(() => selectedDisplay.value != null);

  /// Whether the session is fully ready for interaction (device + display).
  late final isReady = computed(() => hasDevice.value && hasDisplay.value);

  // ── ADB Path ─────────────────────────────────────────────────────────────

  /// Get the current ADB path.
  String get adbPath => _adb.adbPath;

  /// Set a new ADB path and re-validate.
  Future<void> setAdbPath(String path) async {
    _adb.adbPath = path;
    await validateAdb();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Validate the ADB executable and extract its version.
  Future<void> validateAdb() async {
    error.value = null;
    try {
      final valid = await _adb.validate();
      adbValid.value = valid;

      if (valid) {
        final versionOutput = await _adb.version();
        adbVersion.value = parseAdbVersion(versionOutput);
      } else {
        adbVersion.value = '';
        error.value = 'ADB not found or not executable';
      }
    } catch (e) {
      adbValid.value = false;
      adbVersion.value = '';
      error.value = 'ADB validation failed: $e';
    }
  }

  /// Refresh the list of connected devices.
  Future<void> refreshDevices() async {
    if (!adbValid.value) return;

    isLoading.value = true;
    error.value = null;

    try {
      final output = await _adb.devices();
      final parsed = parseDeviceList(output);
      devices.value = parsed;

      // If the previously selected device is no longer in the list, deselect
      if (selectedDevice.value != null &&
          !parsed.contains(selectedDevice.value)) {
        selectedDevice.value = null;
        displays.value = [];
        selectedDisplay.value = null;
      }
    } catch (e) {
      error.value = 'Failed to list devices: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Select a device and automatically refresh its displays.
  Future<void> selectDevice(AdbDevice device) async {
    selectedDevice.value = device;
    selectedDisplay.value = null;
    displays.value = [];
    overlayWindows.value = [];
    await refreshDisplays();
  }

  /// Refresh the display list for the currently selected device.
  Future<void> refreshDisplays() async {
    final device = selectedDevice.value;
    if (device == null || !device.isOnline) return;

    isLoading.value = true;
    error.value = null;

    try {
      final output = await _adb.dumpsysDisplay(device.serial);
      final parsed = parseDisplays(output);
      displays.value = parsed;
      overlayWindows.value = parseOverlayWindows(output);

      // If previously selected display is gone, deselect
      if (selectedDisplay.value != null &&
          !parsed.contains(selectedDisplay.value)) {
        selectedDisplay.value = null;
      }
    } catch (e) {
      error.value = 'Failed to list displays: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Look up how to capture [displayId] by cropping its host display.
  ///
  /// Returns null when [displayId] is not a simulated overlay display, when the
  /// overlay is currently hidden, or when the host display's size is unknown —
  /// in all of those cases there is nothing sensible to crop.
  ///
  /// This re-reads `dumpsys display` rather than using the cached values from
  /// [refreshDisplays], because the user can move or resize the overlay window
  /// at any time and a stale rect silently mirrors the wrong pixels.
  Future<OverlayCaptureSource?> resolveOverlaySource(int displayId) async {
    final device = selectedDevice.value;
    if (device == null || !device.isOnline) return null;

    final output = await _adb.dumpsysDisplay(device.serial);
    final overlays = parseOverlayWindows(output);
    overlayWindows.value = overlays;

    OverlayWindow? overlay;
    for (final candidate in overlays) {
      if (candidate.displayId == displayId) {
        overlay = candidate;
        break;
      }
    }
    if (overlay == null || !overlay.visible) return null;

    // Overlay displays are always composited onto the primary display.
    const hostDisplayId = 0;
    final parsedDisplays = parseDisplays(output);
    DisplayInfo? host;
    for (final candidate in parsedDisplays) {
      if (candidate.id == hostDisplayId) {
        host = candidate;
        break;
      }
    }
    if (host == null) return null;

    return OverlayCaptureSource(
      hostDisplayId: hostDisplayId,
      hostWidth: host.width,
      hostHeight: host.height,
      cropRect: overlay.windowRect,
      overlay: overlay,
    );
  }

  /// Select a display for mirroring and interaction.
  void selectDisplay(DisplayInfo display) {
    selectedDisplay.value = display;
  }

  /// Clear all state — used when disconnecting or resetting.
  void reset() {
    selectedDevice.value = null;
    selectedDisplay.value = null;
    devices.value = [];
    overlayWindows.value = [];
    displays.value = [];
    error.value = null;
  }
}
