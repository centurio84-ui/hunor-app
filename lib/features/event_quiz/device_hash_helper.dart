import 'dart:convert';
import 'dart:typed_data';

import 'device_hash_stub.dart'
    if (dart.library.js_interop) 'device_hash_web.dart' as platform;

/// Generates a deterministic device_hash combining a persistent localStorage seed
/// with basic browser/device attributes, hashed via SHA-256-like FNV/SHA digest.
Future<String> getDeterministicDeviceHash() => platform.getDeviceHashImpl();

/// Downloads PNG bytes on Web (or returns false on non-web platforms).
bool downloadPngBytes(Uint8List bytes, String fileName) =>
    platform.downloadPngBytesImpl(bytes, fileName);

/// Shares poster PNG + clickable URL + caption via Web Share API (mobile/desktop browsers).
/// Returns `'shared'`, `'cancelled'`, or `'unsupported'`.
Future<String> sharePosterWithLink({
  required Uint8List pngBytes,
  required String fileName,
  required String title,
  required String text,
  required String url,
}) =>
    platform.sharePosterWithLinkImpl(
      pngBytes: pngBytes,
      fileName: fileName,
      title: title,
      text: text,
      url: url,
    );

/// Triggers a browser desktop/system Notification on Web if permitted.
Future<bool> showBrowserLeaderNotification({
  required String title,
  required String body,
}) =>
    platform.showBrowserNotificationImpl(title: title, body: body);

String computeDeterministicHexHash(String input) {
  final bytes = utf8.encode(input);
  // 256-bit deterministic multi-lane FNV-1a mix (no external native dependency needed)
  final lanes = <int>[
    0x811c9dc5,
    0x9e3779b9,
    0x85ebca6b,
    0xc2b2ae35,
    0x27d4eb2f,
    0x165667b1,
    0xd3a2646c,
    0xfd7046c5,
  ];
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    final laneIdx = i & 7;
    var h = lanes[laneIdx] ^ b;
    h = (h * 0x01000193) & 0xffffffff;
    lanes[(laneIdx + 1) & 7] =
        (lanes[(laneIdx + 1) & 7] ^ ((h >> 13) | ((h << 19) & 0xffffffff))) &
            0xffffffff;
    lanes[laneIdx] = h;
  }
  return lanes.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
}
