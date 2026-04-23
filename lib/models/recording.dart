import 'touch_action.dart';

/// A recorded sequence of touch interactions on a specific display.
class Recording {
  final String name;
  final DateTime createdAt;
  final int displayId;
  final int displayWidth;
  final int displayHeight;
  final List<TouchAction> actions;

  Recording({
    required this.name,
    required this.createdAt,
    required this.displayId,
    required this.displayWidth,
    required this.displayHeight,
    List<TouchAction>? actions,
  }) : actions = actions ?? [];

  /// Total duration of the recording in milliseconds.
  int get totalDurationMs {
    if (actions.isEmpty) return 0;
    return actions.last.timestampMs;
  }

  /// Number of recorded actions.
  int get actionCount => actions.length;

  Map<String, dynamic> toJson() => {
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'displayId': displayId,
        'displayWidth': displayWidth,
        'displayHeight': displayHeight,
        'actions': actions.map((a) => a.toJson()).toList(),
      };

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      displayId: json['displayId'] as int,
      displayWidth: json['displayWidth'] as int,
      displayHeight: json['displayHeight'] as int,
      actions: (json['actions'] as List<dynamic>)
          .map((a) => TouchAction.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() =>
      'Recording($name, display=$displayId, ${actions.length} actions)';
}
