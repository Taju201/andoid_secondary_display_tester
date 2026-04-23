import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../controllers/device_session.dart';
import '../controllers/display_mirror_controller.dart';
import '../controllers/recording_controller.dart';
import '../models/display_info.dart';
import '../services/adb_service.dart';
import 'adb_path_dialog.dart';
import 'recording_panel.dart';

/// Left sidebar panel containing device/display selection and recording controls.
class DevicePanel extends StatelessWidget {
  final DeviceSession deviceSession;
  final DisplayMirrorController mirrorController;
  final RecordingController recordingController;
  final AdbService adbService;

  const DevicePanel({
    super.key,
    required this.deviceSession,
    required this.mirrorController,
    required this.recordingController,
    required this.adbService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1117),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ADB Config ──
          _buildSection(
            context,
            title: 'ADB',
            trailing: IconButton(
              icon: const Icon(Icons.settings, size: 16),
              onPressed: () => _showAdbPathDialog(context),
              tooltip: 'Configure ADB path',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            child: Watch((context) {
              final valid = deviceSession.adbValid.value;
              final version = deviceSession.adbVersion.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      valid ? Icons.check_circle : Icons.error,
                      size: 14,
                      color: valid
                          ? const Color(0xFF3FB950)
                          : const Color(0xFFF85149),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      valid ? 'v$version' : 'Not found',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          const Divider(height: 1),

          // ── Devices ──
          _buildSection(
            context,
            title: 'DEVICES',
            trailing: Watch((context) {
              final loading = deviceSession.isLoading.value;
              return IconButton(
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                onPressed: loading
                    ? null
                    : () => deviceSession.refreshDevices(),
                tooltip: 'Refresh devices',
                visualDensity: VisualDensity.compact,
              );
            }),
            child: Watch((context) {
              final devices = deviceSession.devices.value;
              final selected = deviceSession.selectedDevice.value;

              if (devices.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    'No devices found',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton(
                      value: selected,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF21262D),
                      style: const TextStyle(fontSize: 13),
                      hint: Text(
                        'Select device...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      items: devices.map((device) {
                        return DropdownMenuItem(
                          value: device,
                          child: Row(
                            children: [
                              Icon(
                                device.isOnline
                                    ? Icons.phone_android
                                    : Icons.phone_disabled,
                                size: 14,
                                color: device.isOnline
                                    ? const Color(0xFF3FB950)
                                    : const Color(0xFFF85149),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  device.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (device) {
                        if (device != null) {
                          mirrorController.stopCapture();
                          deviceSession.selectDevice(device);
                        }
                      },
                    ),
                  ),
                ),
              );
            }),
          ),

          const Divider(height: 1),

          // ── Displays ──
          _buildSection(
            context,
            title: 'DISPLAYS',
            trailing: Watch((context) {
              final hasDevice = deviceSession.hasDevice.value;
              return IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: hasDevice
                    ? () => deviceSession.refreshDisplays()
                    : null,
                tooltip: 'Refresh displays',
                visualDensity: VisualDensity.compact,
              );
            }),
            child: Watch((context) {
              final displayList = deviceSession.displays.value;
              final selected = deviceSession.selectedDisplay.value;

              if (displayList.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    deviceSession.hasDevice.value
                        ? 'No displays found'
                        : 'Select a device first',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }

              return Column(
                children: displayList.map((display) {
                  final isSelected = display == selected;
                  return _buildDisplayTile(
                    display,
                    isSelected: isSelected,
                    onTap: () => _onDisplaySelected(display),
                  );
                }).toList(),
              );
            }),
          ),

          const Divider(height: 1),

          // ── Recording ──
          Expanded(
            child: RecordingPanel(
              recordingController: recordingController,
              deviceSession: deviceSession,
              adbService: adbService,
            ),
          ),

          // ── Error display ──
          Watch((context) {
            final err = deviceSession.error.value;
            if (err == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF85149).withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 14,
                    color: Color(0xFFF85149),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      err,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF85149),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    onPressed: () => deviceSession.error.value = null,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
          child: Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
        ),
        child,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDisplayTile(
    DisplayInfo display, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isSelected
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected
                  ? const Color(0xFF6C5CE7)
                  : Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display.displayLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    '${display.resolution} · ${display.density}dpi',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDisplaySelected(DisplayInfo display) {
    mirrorController.stopCapture();
    deviceSession.selectDisplay(display);

    final device = deviceSession.selectedDevice.value;
    if (device != null) {
      mirrorController.startCapture(device.serial, display.id);
    }
  }

  void _showAdbPathDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AdbPathDialog(
        currentPath: deviceSession.adbPath,
        onPathChanged: (path) async {
          await deviceSession.setAdbPath(path);
          if (deviceSession.adbValid.value) {
            await deviceSession.refreshDevices();
          }
        },
      ),
    );
  }
}
