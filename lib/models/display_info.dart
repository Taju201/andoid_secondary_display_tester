/// Represents an Android display as reported by `dumpsys display`.
class DisplayInfo {
  final int id;
  final String name;
  final int width;
  final int height;
  final int density;

  const DisplayInfo({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.density,
  });

  /// A human-readable label for this display.
  String get displayLabel {
    if (id == 0) return 'Primary ($name)';
    return 'Display $id ($name)';
  }

  /// The aspect ratio of this display (width / height).
  double get aspectRatio => width / height;

  /// Resolution as a readable string.
  String get resolution => '${width}x$height';

  @override
  String toString() =>
      'DisplayInfo(id=$id, name=$name, ${width}x$height, density=$density)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
