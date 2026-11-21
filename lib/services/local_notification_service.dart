import 'dart:async';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Háttérben érkező Firebase Push értesítés kezelő (top-level függvény)
@pragma('vm:entry-point')
Future<void> hunorFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  try {
    final badgeRaw = message.data['badge'] ?? message.data['unread_count'];
    final badgeCount = int.tryParse(badgeRaw?.toString() ?? '') ?? 1;
    await AppBadgePlus.updateBadge(badgeCount);
  } catch (_) {}
}

/// Rendszerszintű értesítés és ikon-jelvény (piros pötty / szám az app ikonon) kezelő.
/// Android 8–16 rendszereken (Samsung OneUI, Xiaomi, Pixel, Honor) a launcher ikonon lévő
/// piros értesítési jelvényt a showBadge: true Android NotificationChannel + aktív értesítés
/// működteti – pontosan úgy, mint a Messenger esetében.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const String _chatChannelId = 'hunor_chat_messages_v1';
  static const String _chatChannelName = 'Csapat üzenetek';
  static const String _chatChannelDesc = 'Olvasatlan csapat chat üzenetek és piros ikon-jelvény';
  static const int _chatNotificationId = 1001;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _firebaseInitialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      );
      await _plugin.initialize(initSettings);

      // Android NotificationChannel létrehozása showBadge: true beállítással
      const androidChannel = AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: _chatChannelDesc,
        importance: Importance.high,
        showBadge: true,
        playSound: true,
        enableVibration: true,
      );

      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(androidChannel);
    } catch (e) {
      debugPrint('[LocalNotificationService] init hiba: $e');
    }
  }

  /// Firebase Cloud Messaging inicializálása és FCM token lekérése
  Future<String?> initializeFirebaseAndGetToken({
    void Function(String title, String body)? onForegroundMessage,
  }) async {
    if (kIsWeb) return null;
    try {
      if (!_firebaseInitialized) {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
        FirebaseMessaging.onBackgroundMessage(hunorFirebaseBackgroundHandler);
        _firebaseInitialized = true;
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ??
            message.data['title']?.toString() ??
            'Új HUNOR üzenet';
        final body = message.notification?.body ??
            message.data['body']?.toString() ??
            'Új olvasatlan üzenet érkezett.';
        onForegroundMessage?.call(title, body);
      });

      return await messaging.getToken();
    } catch (e) {
      debugPrint('[LocalNotificationService] Firebase init hiba: $e');
      return null;
    }
  }

  /// Piros jelvény (ikon badge) + rendszerértesítés megjelenítése olvasatlan üzenetnél
  Future<void> showUnreadChatNotification({
    required int unreadCount,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await initialize();

    try {
      await AppBadgePlus.updateBadge(unreadCount);
    } catch (_) {}

    if (unreadCount <= 0) {
      await clearChatNotifications();
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        _chatChannelId,
        _chatChannelName,
        channelDescription: _chatChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        channelShowBadge: true,
        number: unreadCount,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );
      final darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: unreadCount,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        _chatNotificationId,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] showUnreadChatNotification hiba: $e');
    }
  }

  /// Értesítés és app ikon jelvény törlése, amikor a felhasználó elolvassa az üzeneteket
  Future<void> clearChatNotifications() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_chatNotificationId);
    } catch (_) {}
    try {
      await AppBadgePlus.updateBadge(0);
    } catch (_) {}
  }
}
