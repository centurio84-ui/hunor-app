import 'dart:js_interop';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'device_hash_helper.dart';

const _storageKey = 'hunor_event_quiz_device_seed_v1';

@JS('window.localStorage.getItem')
external String? _lsGetItem(String key);

@JS('window.localStorage.setItem')
external void _lsSetItem(String key, String value);

@JS('window.navigator.userAgent')
external String get _userAgent;

@JS('window.navigator.language')
external String get _language;

@JS('window.navigator.hardwareConcurrency')
external int? get _hardwareConcurrency;

@JS('window.screen.width')
external int get _screenWidth;

@JS('window.screen.height')
external int get _screenHeight;

@JS('window.screen.colorDepth')
external int get _colorDepth;

@JS('document.createElement')
external _AnchorElement _createElement(String tag);

@JS('URL.createObjectURL')
external String _createObjectUrl(_JsBlob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

@JS('Blob')
extension type _JsBlob._(JSObject _) implements JSObject {
  external factory _JsBlob(JSArray<JSAny> parts, _BlobPropertyBag options);
}

@JS('Notification')
extension type _WebNotification._(JSObject _) implements JSObject {
  external factory _WebNotification(String title, _WebNotifOptions options);
  external static String get permission;
  external static JSPromise<JSString> requestPermission();
}

extension type _WebNotifOptions._(JSObject _) implements JSObject {
  external factory _WebNotifOptions({String body, String icon, String tag});
}

extension type _BlobPropertyBag._(JSObject _) implements JSObject {
  external factory _BlobPropertyBag({String type});
}

extension type _AnchorElement(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

Future<String> getDeviceHashImpl() async {
  String? seed;
  try {
    seed = _lsGetItem(_storageKey);
  } catch (_) {}

  if (seed == null || seed.trim().isEmpty) {
    seed = const Uuid().v4();
    try {
      _lsSetItem(_storageKey, seed);
    } catch (_) {}
  }

  String attrs = '';
  try {
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    attrs =
        '$_userAgent|$_language|${_hardwareConcurrency ?? 0}|${_screenWidth}x$_screenHeight|$_colorDepth|$tz';
  } catch (_) {
    attrs = 'web';
  }

  return 'hq_${computeDeterministicHexHash('$seed|$attrs')}';
}

bool downloadPngBytesImpl(Uint8List bytes, String fileName) {
  try {
    final jsBytes = bytes.toJS;
    final blob = _JsBlob([jsBytes].toJS, _BlobPropertyBag(type: 'image/png'));
    final url = _createObjectUrl(blob);
    final anchor = _createElement('a')
      ..href = url
      ..download = fileName;
    anchor.click();
    Future<void>.delayed(const Duration(seconds: 2), () {
      try {
        _revokeObjectUrl(url);
      } catch (_) {}
    });
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> showBrowserNotificationImpl({
  required String title,
  required String body,
}) async {
  try {
    var perm = _WebNotification.permission;
    if (perm == 'default') {
      final res = await _WebNotification.requestPermission().toDart;
      perm = res.toDart;
    }
    if (perm != 'granted') return false;
    _WebNotification(
      title,
      _WebNotifOptions(
        body: body,
        icon: '/hunor-app-icon.svg',
        tag: 'hunor-quiz-hourly-leader',
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}
