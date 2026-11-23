import 'dart:async';
import 'dart:typed_data';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Háttérben / alvó módban érkező Firebase Push értesítés kezelő (top-level függvény)
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
  try {
    final isAlert = message.data.containsKey('alert_id') ||
        message.data['alert_type'] == 'alert' ||
        message.data['alert_type'] == 'standby';
    if (isAlert) {
      await LocalNotificationService.instance.initialize();
      final title = message.notification?.title ??
          message.data['title']?.toString() ??
          '🚨 HUNOR RIASZTÁS';
      final body = message.notification?.body ??
          message.data['body']?.toString() ??
          'Éles riasztási esemény érkezett! Nyisd meg az alkalmazást!';
      await LocalNotificationService.instance.showEmergencyAlertNotification(
        title: title,
        body: body,
      );
    } else if (message.notification == null &&
        (message.data['title'] != null || message.data['body'] != null)) {
      await LocalNotificationService.instance.initialize();
      final badgeRaw = message.data['badge'] ?? message.data['unread_count'];
      final badgeCount = int.tryParse(badgeRaw?.toString() ?? '') ?? 1;
      await LocalNotificationService.instance.showUnreadChatNotification(
        unreadCount: badgeCount > 0 ? badgeCount : 1,
        title: message.data['title']?.toString() ?? 'HUNOR értesítés',
        body: message.data['body']?.toString() ?? 'Új üzenet vagy esemény érkezett.',
      );
    }
  } catch (_) {}
}

/// Rendszerszintű értesítés, ikon-jelvény (piros pötty/szám) és vészriasztási sziréna kezelő.
/// - Chat üzenetek: 'hunor_chat_messages_v1' csatorna (showBadge: true)
/// - Éles riasztás: 'hunor_alerts' csatorna (Importance.max, AudioAttributesUsage.alarm,
///   hunor_siren.wav hang, fullScreenIntent: true, FLAG_INSISTENT) – némított vagy alvó
///   telefonon is megszólal az ébresztő (ALARM) hangcsatornán!
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const String _chatChannelId = 'hunor_chat_messages_v2';
  static const String _chatChannelName = 'Üzenetek és események';
  static const String _chatChannelDesc =
      'Chat üzenetek, új események és általános értesítések (egyedi hangjelzéssel)';
  static const int _chatNotificationId = 1001;

  static const String _alertChannelId = 'hunor_alerts';
  static const String _alertChannelName = 'HUNOR Éles Riasztás (Sziréna)';
  static const String _alertChannelDesc =
      'Kiemelt fontosságú vészriasztás szirénahanggal, alvó és némított módban is';
  static const int _alertNotificationId = 2001;

  static final Int64List _emergencyVibration = Int64List.fromList([0, 600, 250, 600, 250, 1000]);

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

      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // Régi v1 csatorna eltávolítása, hogy Android biztosan az új üzenethangot használja
      try {
        await androidImpl?.deleteNotificationChannel('hunor_chat_messages_v1');
      } catch (_) {}

      // 1. Chat & esemény értesítési csatorna (iPhone-stílusú üzenethang + piros ikon-jelvény)
      const chatChannel = AndroidNotificationChannel(
        _chatChannelId,
        _chatChannelName,
        description: _chatChannelDesc,
        importance: Importance.high,
        showBadge: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('hunor_message_tone'),
        audioAttributesUsage: AudioAttributesUsage.notification,
        enableVibration: true,
      );
      await androidImpl?.createNotificationChannel(chatChannel);

      // 2. Éles Riasztás csatorna (SZIRÉNA + ALARM hangcsatorna + Max prioritás)
      final alertChannel = AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: _alertChannelDesc,
        importance: Importance.max,
        showBadge: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('hunor_siren'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: _emergencyVibration,
      );
      await androidImpl?.createNotificationChannel(alertChannel);
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
        criticalAlert: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ??
            message.data['title']?.toString() ??
            'Új HUNOR értesítés';
        final body = message.notification?.body ??
            message.data['body']?.toString() ??
            'Új értesítés érkezett.';

        final isAlert = message.data.containsKey('alert_id') ||
            message.data['alert_type'] == 'alert' ||
            message.data['alert_type'] == 'standby';

        if (isAlert) {
          unawaited(showEmergencyAlertNotification(title: title, body: body));
        } else {
          onForegroundMessage?.call(title, body);
        }
      });

      return await messaging.getToken();
    } catch (e) {
      debugPrint('[LocalNotificationService] Firebase init hiba: $e');
      return null;
    }
  }

  /// Kiemelt felugró riasztás + HUNOR sziréna az ébresztő (ALARM) csatornán.
  /// Alvó módban és némított csengőhangnál is megszólal és felugró kártyát nyit.
  Future<void> showEmergencyAlertNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await initialize();

    try {
      await AppBadgePlus.updateBadge(1);
    } catch (_) {}

    try {
      final androidDetails = AndroidNotificationDetails(
        _alertChannelId,
        _alertChannelName,
        channelDescription: _alertChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('hunor_siren'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: _emergencyVibration,
        channelShowBadge: true,
        number: 1,
        autoCancel: true,
        ongoing: false,
        // FLAG_INSISTENT (4): ismétli a szirénát, amíg a felhasználó rá nem koppint
        additionalFlags: Int32List.fromList(<int>[4]),
        icon: '@mipmap/ic_launcher',
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        _alertNotificationId,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] showEmergencyAlertNotification hiba: $e');
    }
  }

  /// Piros jelvény (ikon badge) + rendszerértesítés megjelenítése olvasatlan chat üzenetnél
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
        sound: const RawResourceAndroidNotificationSound('hunor_message_tone'),
        audioAttributesUsage: AudioAttributesUsage.notification,
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

  /// Chat értesítés és app ikon jelvény törlése, amikor a felhasználó elolvassa az üzeneteket
  Future<void> clearChatNotifications() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_chatNotificationId);
    } catch (_) {}
    try {
      await AppBadgePlus.updateBadge(0);
    } catch (_) {}
  }

  /// Riasztási sziréna leállítása / értesítés törlése
  Future<void> clearEmergencyAlert() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_alertNotificationId);
    } catch (_) {}
  }
}
