# Android Secondary Display Tester

Desktop Flutter application for testing Android secondary displays from Windows and Linux using ADB.

## Download

Prebuilt Windows builds are attached to each
[GitHub Release](https://github.com/Taju201/andoid_secondary_display_tester/releases).

1. Download `adb-display-tester-windows-x64.zip`.
2. Extract the whole folder — the `.exe` will not start on its own. It needs
   `flutter_windows.dll`, `icudtl.dat` and the `data/` directory that ship
   alongside it.
3. Run `andoid_secondary_display_tester.exe`.

The app does not bundle ADB. Install
[Android platform-tools](https://developer.android.com/tools/releases/platform-tools)
and make sure `adb` is on your `PATH`, or point the app at an `adb` executable
through the gear icon next to the ADB status.

Windows SmartScreen will warn about an unsigned executable — the builds are not
code-signed. Choose *More info* → *Run anyway*, or build from source.

Untagged builds from `main` are also available as workflow artifacts on the
[Actions tab](https://github.com/Taju201/andoid_secondary_display_tester/actions),
though those require being signed in to GitHub to download.

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
4. The app repeatedly captures that display through `adb exec-out` — see [Capture Modes](#capture-modes).
5. The latest frame is rendered inside a desktop viewer.
6. Desktop pointer input is translated back into the Android display's coordinate space.
7. ADB shell input commands are sent to the device using the selected display id.

## Capture Modes

The app picks how to capture a display automatically. There is no setting to
choose between them.

### Direct capture

`adb exec-out screencap -p -d <displayId>`, which is what real displays support.
Full fidelity, and the default for every display.

### Overlay crop (automatic fallback)

`screencap -d` addresses **SurfaceFlinger** displays. A Developer Options
"simulated secondary display" is not one — the system composites it as a
floating window on the primary display, so `screencap` refuses it:

```console
$ adb exec-out screencap -p -d 2
Failed to take screenshot. Status: -2
Capturing failed.
```

Note that `screencap` exits 0 here and writes that text to stdout, so the exit
code alone does not reveal the failure.

When direct capture fails, the app looks the display up in the
`OverlayDisplayAdapter` section of `dumpsys display`. If it turns out to be an
overlay, the app switches to capturing the **host** display and cropping the
overlay's window region out of each frame. The viewer shows an amber
`Overlay crop` badge whenever this mode is active, because the frames are
lower fidelity than a direct capture:

- The overlay window is composited at `alpha=0.8`, so cropped colors are
  blended with whatever is behind it on the host display.
- The overlay's title (`Overlay #1: 720x480, 142 dpi`) is drawn over the top of
  its own content and lands in the crop.
- If the overlay is scaled below its logical resolution, so is the mirror. The
  badge shows the scale when it is under 100%.
- Anything the system draws above the overlay — a dialog, the notification
  shade, an IME — lands in the crop too.
- The host display has to be awake. When the device's screen sleeps, the host
  screenshot goes black and so does the mirror.

Touch input is not affected by the mode. Pointer coordinates are always mapped
against the display's own logical resolution and sent with
`input -d <displayId>`, independent of how the frame was obtained.

The overlay's position and size are re-read every couple of seconds, so moving
or resizing the overlay on the device keeps mirroring correctly.

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
