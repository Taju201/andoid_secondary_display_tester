# Android Secondary Display Tester

Desktop Flutter application for testing Android secondary displays from Windows and Linux using ADB.

## Overview

Android's built-in secondary display emulation in Developer Options is useful, but it does not provide desktop touch input. This project fills that gap by mirroring a selected Android display into a desktop window and forwarding pointer interactions back to the device through ADB.

The goal is to make secondary-display UI testing easier without requiring custom hardware or on-device manual interaction.

## Planned Capabilities

- Detect a system-installed `adb` executable.
- List connected Android devices.
- Discover available displays on the selected device.
- Mirror one selected display in a desktop viewer.
- Convert desktop pointer input into Android display coordinates.
- Send tap, swipe, and long-press gestures to the selected display.
- Record interaction flows with timing and coordinate data.
- Save and load recordings as JSON.
- Replay recordings for repeatable testing scenarios.

## V1 Scope

### Included

- Flutter desktop support for Windows and Linux.
- One active device at a time.
- One active display at a time.
- Snapshot-based screen capture via ADB.
- Tap, swipe, and long-press injection.
- Human-readable JSON recordings.

### Not included

- Bundled ADB binaries.
- Multi-device simultaneous control.
- Multi-display simultaneous mirroring.
- Full live video streaming.
- Compatibility fallbacks for older Android versions.

## Architecture

The app is intended to be structured around four main areas:

### `AdbService`

- Resolve and validate the configured `adb` path.
- Execute `adb devices -l`, `shell`, and `exec-out` commands.
- Normalize command output and errors.

### `DeviceSession`

- Store the active ADB config.
- Manage discovered devices and displays.
- Own selection state and compatibility status.

### `DisplayMirrorController`

- Poll screenshots for the selected display.
- Decode and publish mirror frames.
- Track resolution, orientation, refresh status, and failures.

### `InteractionRecorder`

- Record pointer gestures and delays.
- Save and load JSON scripts.
- Replay scripts against the selected device/display.

## How Mirroring Works

1. The user selects an Android device.
2. The app queries the device for available displays.
3. The user selects one display as the active target.
4. The app repeatedly captures that display through `adb exec-out`.
5. The latest frame is rendered inside a desktop viewer.
6. Desktop pointer input is translated back into the Android display's coordinate space.
7. ADB shell input commands are sent to the device using the selected display id.

## Recording Format

Recordings are planned as JSON files that include:

- A schema version.
- Device metadata for traceability.
- Display metadata, including display id and resolution.
- Ordered touch actions.
- Timing information between actions.

Supported action types for v1:

- `tap`
- `swipe`
- `longPress`

## Development Notes

### Prerequisites

- Flutter SDK with Windows and Linux desktop support enabled.
- Android Debug Bridge (`adb`) installed on the system.
- A connected Android device with support for display-targeted shell input.

### Typical commands

```powershell
flutter pub get
flutter run -d windows
flutter test
```

On Linux, replace the desktop target as appropriate for the local Flutter setup.

## Status

This repository is currently being bootstrapped as a greenfield project. The product direction and implementation plan are defined, and the next step is wiring the Flutter desktop scaffold and app layers described above.

## Roadmap

- Scaffold the Flutter desktop application.
- Implement ADB discovery and validation.
- Add device and display discovery.
- Implement snapshot-based display mirroring.
- Add pointer-to-touch input mapping.
- Add recording, persistence, and replay.
- Harden parsing and command generation with tests.

## License

Add the project license here once it is selected.
