import 'dart:convert';
import 'dart:typed_data';

/// The 8-byte PNG file signature.
const List<int> pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// Whether [bytes] starts with the PNG signature.
///
/// `screencap` exits 0 even when it cannot capture the requested display — it
/// writes a plain-text error to stdout instead of a PNG. Checking the signature
/// is what separates "here is a frame" from "here is an error message that
/// would blow up the image decoder".
bool isPngData(Uint8List bytes) {
  if (bytes.length < pngSignature.length) return false;
  for (var i = 0; i < pngSignature.length; i++) {
    if (bytes[i] != pngSignature[i]) return false;
  }
  return true;
}

/// Turn a non-PNG `screencap` payload into a one-line human-readable reason.
///
/// Typical payload for an uncapturable display:
/// `Failed to take screenshot. Status: -2\nCapturing failed.\n`
String describeScreencapFailure(Uint8List bytes) {
  if (bytes.isEmpty) {
    return 'screencap returned no data';
  }

  final text = _decodeText(bytes).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) {
    return 'screencap returned ${bytes.length} bytes that are not a PNG';
  }

  const maxLength = 200;
  if (text.length > maxLength) {
    return '${text.substring(0, maxLength)}…';
  }
  return text;
}

String _decodeText(Uint8List bytes) {
  // Cap the scan — a truncated or corrupt PNG should not be dumped wholesale
  // into an error message.
  final head = bytes.length > 512 ? bytes.sublist(0, 512) : bytes;
  final decoded = utf8.decode(head, allowMalformed: true);

  // Keep only printable characters so binary garbage does not reach the UI.
  final printable =
      decoded.replaceAll(RegExp(r'[^\x20-\x7E\r\n\t]'), ' ');
  return printable;
}
