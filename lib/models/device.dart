/// Represents a connected Android device as reported by `adb devices -l`.
class AdbDevice {
  final String serial;
  final String state;
  final String? model;
  final String? product;
  final String? device;
  final String? transportId;

  const AdbDevice({
    required this.serial,
    required this.state,
    this.model,
    this.product,
    this.device,
    this.transportId,
  });

  /// Parse a single line from `adb devices -l` output.
  ///
  /// Example line:
  /// ```
  /// emulator-5554          device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa transport_id:1
  /// ```
  factory AdbDevice.fromDevicesLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      throw FormatException('Invalid device line: $line');
    }

    final serial = parts[0];
    final state = parts[1];

    String? model;
    String? product;
    String? device;
    String? transportId;

    for (final part in parts.skip(2)) {
      final kv = part.split(':');
      if (kv.length == 2) {
        switch (kv[0]) {
          case 'model':
            model = kv[1];
          case 'product':
            product = kv[1];
          case 'device':
            device = kv[1];
          case 'transport_id':
            transportId = kv[1];
        }
      }
    }

    return AdbDevice(
      serial: serial,
      state: state,
      model: model,
      product: product,
      device: device,
      transportId: transportId,
    );
  }

  /// A human-readable display name for this device.
  String get displayName {
    if (model != null) return '$model ($serial)';
    return serial;
  }

  /// Whether the device is online and ready for commands.
  bool get isOnline => state == 'device';

  /// Whether the device is connected but not authorized.
  bool get isUnauthorized => state == 'unauthorized';

  @override
  String toString() => 'AdbDevice($serial, state=$state, model=$model)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdbDevice &&
          runtimeType == other.runtimeType &&
          serial == other.serial;

  @override
  int get hashCode => serial.hashCode;
}
