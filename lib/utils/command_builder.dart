// Build ADB shell input commands for touch interactions.
//
// These are pure functions that produce command strings for use with
// `adb -s <serial> shell <command>`. They do not execute anything.

/// Build a tap command string targeting a specific display.
///
/// Example: `input -d 2 tap 540 1170`
String buildTapCommand(int displayId, double x, double y) {
  return 'input -d $displayId tap ${x.round()} ${y.round()}';
}

/// Build a swipe command string targeting a specific display.
///
/// Example: `input -d 2 swipe 100 200 400 600 300`
String buildSwipeCommand(
  int displayId,
  double x1,
  double y1,
  double x2,
  double y2,
  int durationMs,
) {
  return 'input -d $displayId swipe '
      '${x1.round()} ${y1.round()} '
      '${x2.round()} ${y2.round()} '
      '$durationMs';
}

/// Build a long-press command string targeting a specific display.
///
/// Implemented as a zero-distance swipe with the given duration.
///
/// Example: `input -d 2 swipe 540 1170 540 1170 1000`
String buildLongPressCommand(
  int displayId,
  double x,
  double y,
  int durationMs,
) {
  return buildSwipeCommand(displayId, x, y, x, y, durationMs);
}
