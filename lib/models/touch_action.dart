/// The type of touch interaction recorded or replayed.
enum TouchActionType {
  tap,
  swipe,
  longPress;

  String toJson() => name;

  static TouchActionType fromJson(String json) {
    return TouchActionType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => throw FormatException('Unknown TouchActionType: $json'),
    );
  }
}

/// A single recorded touch interaction with coordinates, timing, and type.
class TouchAction {
  final TouchActionType type;

  /// Start coordinates on the Android display (not the view).
  final double x;
  final double y;

  /// End coordinates for swipe actions. Null for tap/longPress.
  final double? endX;
  final double? endY;

  /// Duration in milliseconds.
  /// - For swipe: the swipe duration.
  /// - For longPress: the hold duration.
  /// - For tap: null.
  final int? durationMs;

  /// Timestamp in milliseconds relative to the start of the recording.
  final int timestampMs;

  const TouchAction({
    required this.type,
    required this.x,
    required this.y,
    this.endX,
    this.endY,
    this.durationMs,
    required this.timestampMs,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toJson(),
        'x': x,
        'y': y,
        if (endX != null) 'endX': endX,
        if (endY != null) 'endY': endY,
        if (durationMs != null) 'durationMs': durationMs,
        'timestampMs': timestampMs,
      };

  factory TouchAction.fromJson(Map<String, dynamic> json) {
    return TouchAction(
      type: TouchActionType.fromJson(json['type'] as String),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      endX: (json['endX'] as num?)?.toDouble(),
      endY: (json['endY'] as num?)?.toDouble(),
      durationMs: json['durationMs'] as int?,
      timestampMs: json['timestampMs'] as int,
    );
  }

  /// Human-readable summary for display in the recording panel.
  String get summary {
    switch (type) {
      case TouchActionType.tap:
        return 'tap(${x.toInt()}, ${y.toInt()})';
      case TouchActionType.swipe:
        return 'swipe(${x.toInt()},${y.toInt()} → ${endX?.toInt()},${endY?.toInt()}) ${durationMs}ms';
      case TouchActionType.longPress:
        return 'longPress(${x.toInt()}, ${y.toInt()}) ${durationMs}ms';
    }
  }

  @override
  String toString() => 'TouchAction($summary @ ${timestampMs}ms)';
}
