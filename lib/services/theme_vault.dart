import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ThemeVault {
  Future<String?> readTheme({String? userId, String? organizationId});
  Future<void> writeTheme(String themeId, {String? userId, String? organizationId});
  Future<void> clearForUser(String userId);
}

class DeviceThemeVault implements ThemeVault {
  static const _lastThemeKey = 'rescue.theme.last_active';
  final FlutterSecureStorage storage;

  DeviceThemeVault({FlutterSecureStorage? storage})
      : storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  String _scopedKey(String userId, String organizationId) =>
      'rescue.theme.user_${userId}_org_$organizationId';

  @override
  Future<String?> readTheme({String? userId, String? organizationId}) async {
    try {
      if (userId != null && organizationId != null) {
        final scoped = await storage.read(key: _scopedKey(userId, organizationId));
        if (scoped != null && scoped.isNotEmpty) return scoped;
      }
      return await storage.read(key: _lastThemeKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeTheme(String themeId, {String? userId, String? organizationId}) async {
    try {
      await storage.write(key: _lastThemeKey, value: themeId);
      if (userId != null && organizationId != null) {
        await storage.write(key: _scopedKey(userId, organizationId), value: themeId);
      }
    } catch (_) {}
  }

  @override
  Future<void> clearForUser(String userId) async {
    try {
      // Törléskor a globális utolsó téma kulcsát is töröljük vagy visszaállítjuk
      await storage.delete(key: _lastThemeKey);
    } catch (_) {}
  }
}

class InMemoryThemeVault implements ThemeVault {
  String? lastTheme;
  final Map<String, String> _scoped = {};

  InMemoryThemeVault({this.lastTheme});

  @override
  Future<String?> readTheme({String? userId, String? organizationId}) async {
    if (userId != null && organizationId != null) {
      final key = '${userId}_$organizationId';
      if (_scoped.containsKey(key)) return _scoped[key];
    }
    return lastTheme;
  }

  @override
  Future<void> writeTheme(String themeId, {String? userId, String? organizationId}) async {
    lastTheme = themeId;
    if (userId != null && organizationId != null) {
      _scoped['${userId}_$organizationId'] = themeId;
    }
  }

  @override
  Future<void> clearForUser(String userId) async {
    _scoped.removeWhere((key, _) => key.startsWith('${userId}_'));
    lastTheme = null;
  }
}
