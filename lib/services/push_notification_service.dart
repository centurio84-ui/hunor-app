import 'dart:async';
import 'package:flutter/foundation.dart';

enum NotificationType {
  alert,
  event,
  news,
  system,
}

class AppPushNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? targetId; // alertId, eventId, vagy newsId
  final DateTime receivedAt;
  final Map<String, dynamic> data;

  const AppPushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.targetId,
    required this.receivedAt,
    this.data = const {},
  });
}

abstract class PushNotificationService {
  Future<void> initialize();
  Future<String?> getDeviceToken();
  Stream<AppPushNotification> get onNotificationReceived;
  Stream<AppPushNotification> get onNotificationOpened;
  Future<void> setEnabled(bool enabled);
}

class MockPushNotificationService implements PushNotificationService {
  final StreamController<AppPushNotification> _receivedCtrl = StreamController<AppPushNotification>.broadcast();
  final StreamController<AppPushNotification> _openedCtrl = StreamController<AppPushNotification>.broadcast();
  bool _enabled = true;
  String _mockToken = 'mock-fcm-token-123456789';

  @override
  Future<void> initialize() async {
    debugPrint('[PushService] Mock push notification service initialized.');
  }

  @override
  Future<String?> getDeviceToken() async {
    return _enabled ? _mockToken : null;
  }

  @override
  Stream<AppPushNotification> get onNotificationReceived => _receivedCtrl.stream;

  @override
  Stream<AppPushNotification> get onNotificationOpened => _openedCtrl.stream;

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
  }

  /// Teszt célra: push értesítés szimulációja
  void simulateIncomingNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? targetId,
    Map<String, dynamic>? data,
  }) {
    if (!_enabled) return;
    final notif = AppPushNotification(
      id: 'mock-notif-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      targetId: targetId,
      receivedAt: DateTime.now(),
      data: data ?? {},
    );
    _receivedCtrl.add(notif);
  }

  void simulateNotificationTap(AppPushNotification notif) {
    _openedCtrl.add(notif);
  }

  void dispose() {
    _receivedCtrl.close();
    _openedCtrl.close();
  }
}
