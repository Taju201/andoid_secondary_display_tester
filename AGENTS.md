# AGENTS.md

This repository is a greenfield Flutter desktop application for testing Android secondary displays from Windows and Linux using ADB.

## Mission

Build a desktop tool that:

- Detects a system-installed `adb` executable.
- Lists connected Android devices.
- Lists available Android displays for the selected device.
- Mirrors one selected display using repeated screenshot capture.
- Maps desktop pointer input to Android display coordinates.
- Sends touch events to the selected display with ADB shell commands.
- Records and replays touch interaction scripts as JSON.

## Product Boundaries

### In scope for v1

- Flutter desktop app for Windows and Linux.
- One active Android device at a time.
- One active Android display at a time.
- Snapshot-based mirroring, not continuous video streaming.
- Tap, swipe, and long-press interactions.
- JSON-based recording and replay.
- Modern Android devices only.

### Out of scope for v1

- Bundling ADB binaries.
- Supporting multiple mirrored displays at once.
- Supporting multiple active devices at once.
- Broad backward-compatibility fallback logic for older Android versions.
- Full automation DSL beyond recorded JSON scripts.
- Production-grade packaging or installer work unless explicitly requested.

## Technical Direction

Organize the app around these core layers:

1. `AdbService`
   - Resolve and validate ADB path.
   - Run `adb devices -l`.
   - Run device-scoped `shell` and `exec-out` commands.
   - Surface stdout/stderr/exit failures clearly.

2. `DeviceSession`
   - Own active ADB config, connected devices, selected device, discovered displays, and compatibility state.
   - Coordinate refreshes and selection changes.

3. `DisplayMirrorController`
   - Poll screenshots for the selected display.
   - Decode frames off the UI thread where practical.
   - Expose frame, size, rotation, refresh state, and error state.
   - Fall back to overlay-crop capture when direct capture is refused, and
     expose which mode is active so the UI can flag degraded frames.

4. `InteractionRecorder`
   - Record tap/swipe/long-press actions with timing.
   - Save and load scripts as JSON.
   - Replay scripts through `AdbService`.

## Suggested Project Structure

Use a structure close to:

```text
lib/
  app/
  models/
  services/
  controllers/
  widgets/
  utils/
test/
```

Keep UI code separate from ADB command construction and parsing logic so those parts are easy to unit test.

## Implementation Rules

- Prefer pure Dart and Flutter SDK libraries unless an external dependency is clearly justified.
- Keep parsing, command generation, coordinate mapping, and recording logic unit-testable without a real device.
- Avoid hard-coding Android output assumptions in UI widgets; parse shell output in dedicated helpers.
- Handle unsupported-device cases explicitly and disable actions rather than failing silently.
- Preserve aspect ratio when rendering the mirrored display and account for letterboxing when mapping input coordinates.
- Treat replay timing as part of the recorded behavior.

## ADB Expectations

The app should work with a user-provided or system-resolved `adb` path.

Expected command categories include:

- `adb version`
- `adb devices -l`
- `adb -s <serial> shell ...`
- `adb -s <serial> exec-out ...`

Display-targeted input should assume modern Android shell support such as:

- `input -d <displayId> tap x y`
- `input -d <displayId> swipe x1 y1 x2 y2 duration`

### Simulated secondary displays

`screencap -d` takes a **SurfaceFlinger** display id, not the logical display id
from `dumpsys display`. Developer Options "simulated secondary displays" have no
SurfaceFlinger display of their own — they are windows composited onto the
primary display — so `screencap` refuses them with exit code **0** and a
plain-text `Failed to take screenshot. Status: -2` on stdout. Screenshot
payloads must therefore be validated against the PNG signature, not the exit
code.

For those displays the app captures the host display and crops the overlay's
window rect, read from the `OverlayDisplayAdapter` section of `dumpsys display`
(`mWindowParams={(x,y)(WxH) ...}`) and paired to a logical display id through
`uniqueId "overlay:<n>"`. This is a lower-fidelity frame — the overlay is
composited at `alpha=0.8`, its title is drawn over its own content, and it may
be scaled down — so the mode must stay visible in the UI. Input is unaffected
and still targets the logical display at its full resolution.

## Testing Expectations

Add automated coverage for:

- ADB executable validation.
- Device parsing.
- Display parsing.
- Coordinate mapping with scaling and letterboxing.
- Input command generation.
- Capture loop recovery behavior, including the automatic fallback to overlay-crop capture.
- Overlay window parsing and crop-region geometry.
- Recording JSON serialization and replay timing.

Manual checks should verify:

- Device selection.
- Display selection.
- Mirroring.
- Tap/swipe/long-press forwarding.
- Recording save/load/replay.

## Workflow Notes

- This repo may stay partially scaffolded while the desktop app is being bootstrapped.
- If Flutter CLI behavior is slow or unreliable in the environment, preserve progress in source files and docs rather than blocking on tooling.
- Do not add fallback support for unsupported Android devices unless the task explicitly expands scope. The overlay-crop capture mode is an explicit exception — it is the only way to mirror a simulated secondary display, and it should not be removed as "compatibility fallback logic".
