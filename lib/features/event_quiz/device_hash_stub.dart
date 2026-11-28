import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'device_hash_helper.dart';

const _storageKey = 'hunor_event_quiz_device_seed_v1';

Future<String> getDeviceHashImpl() async {
  final prefs = await SharedPreferences.getInstance();
  var seed = prefs.getString(_storageKey);
  if (seed == null || seed.isEmpty) {
    seed = const Uuid().v4();
    await prefs.setString(_storageKey, seed);
  }
  return 'hq_${computeDeterministicHexHash('$seed|native_client')}';
}

bool downloadPngBytesImpl(Uint8List bytes, String fileName) => false;

Future<bool> copyPosterImageToClipboardImpl(Uint8List pngBytes) async => false;

Future<String> sharePosterWithLinkImpl({
  required Uint8List pngBytes,
  required String fileName,
  required String title,
  required String text,
  required String url,
}) async =>
    'unsupported';

Future<bool> showBrowserNotificationImpl({
  required String title,
  required String body,
}) async =>
    false;
