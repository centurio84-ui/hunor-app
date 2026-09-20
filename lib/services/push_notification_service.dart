import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_store.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // iOS displays notification payloads in the foreground because of
      // setForegroundNotificationPresentationOptions above. Android foreground
      // presentation can be added later with a local-notifications plugin.
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await registerCurrentDevice();
    }
  }

  static Future<void> registerCurrentDevice() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    if (Platform.isIOS) {
      // Firebase recommends waiting until the APNs token is available before
      // making FCM token calls on Apple platforms.
      for (var i = 0; i < 10; i++) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }
  }

  static Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('device_tokens').upsert(
      {
        'member_id': user.id,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'member_id,token',
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background notification messages are displayed by the operating system.
}
