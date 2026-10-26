import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/models/theme_config.dart';
import 'package:hunor_app/services/theme_controller.dart';
import 'package:hunor_app/services/theme_service.dart';
import 'package:hunor_app/services/theme_vault.dart';

class FakeThemeService implements ThemeService {
  ThemeContext? currentContext;
  final StreamController<void> _invalidationController = StreamController<void>.broadcast();
  int setThemeCalls = 0;
  String? lastSetThemeId;
  int? lastExpectedVersion;
  bool shouldThrowConflictOnce = false;

  FakeThemeService({this.currentContext});

  @override
  Future<ThemeContext> getThemeContext(String organizationId) async {
    if (currentContext != null) {
      return currentContext!;
    }
    return ThemeContext(
      contractVersion: 'rp-theme-1',
      organizationId: organizationId,
      activeThemeId: 'weekday-01-alpin',
      themeSource: 'system',
    );
  }

  @override
  Future<List<ThemeCatalogItem>> getThemeCatalog() async {
    return RescueThemeRegistry.allThemes
        .map((t) => ThemeCatalogItem(id: t.id, name: t.name, group: t.group, primaryHex: '#000000'))
        .toList();
  }

  @override
  Future<ThemeMutationResult> setMyTheme({
    required String organizationId,
    required String themeId,
    required int? expectedVersion,
  }) async {
    setThemeCalls++;
    lastSetThemeId = themeId;
    lastExpectedVersion = expectedVersion;

    if (shouldThrowConflictOnce) {
      shouldThrowConflictOnce = false;
      return ThemeMutationResult.conflict(
        message: 'Version conflict',
        latestContext: ThemeContext(
          contractVersion: 'rp-theme-1',
          organizationId: organizationId,
          activeThemeId: 'weekday-05-torzs',
          themeSource: 'user',
          userPreference: UserThemePreference(
            themeId: 'weekday-05-torzs',
            version: 10,
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ),
      );
    }

    final newVersion = (expectedVersion ?? 0) + 1;
    currentContext = ThemeContext(
      contractVersion: 'rp-theme-1',
      organizationId: organizationId,
      activeThemeId: themeId,
      themeSource: 'user',
      userPreference: UserThemePreference(
        themeId: themeId,
        version: newVersion,
        updatedAt: DateTime.now().toIso8601String(),
      ),
    );

    return ThemeMutationResult.success(newVersion);
  }

  @override
  Stream<void> subscribeToThemeChanges({
    required String organizationId,
    required String userId,
  }) {
    return _invalidationController.stream;
  }

  void emitRealtimeInvalidation() {
    _invalidationController.add(null);
  }

  @override
  void dispose() {
    _invalidationController.close();
  }
}

void main() {
  group('ThemeController', () {
    late InMemoryThemeVault vault;
    late FakeThemeService service;
    late ThemeController controller;

    setUp(() {
      vault = InMemoryThemeVault();
      service = FakeThemeService();
      controller = ThemeController(themeService: service, vault: vault);
    });

    tearDown(() {
      controller.dispose();
      service.dispose();
    });

    test('initializes immediately from local cache (flash-free)', () async {
      await vault.writeLastThemeId('weekday-04-medic');
      await controller.initialize();

      expect(controller.activeThemeId, 'weekday-04-medic');
      expect(controller.currentThemeDefinition.name, 'Medic');
      expect(controller.initialized, isTrue);
    });

    test('onUserSignedIn loads server context and updates local cache', () async {
      await controller.initialize();
      service.currentContext = ThemeContext(
        contractVersion: 'rp-theme-1',
        organizationId: 'org-test-1',
        activeThemeId: 'weekday-03-k9',
        themeSource: 'organization',
      );

      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-test-1');

      expect(controller.activeThemeId, 'weekday-03-k9');
      expect(controller.contextData?.themeSource, 'organization');
      expect(await vault.readLastThemeId(), 'weekday-03-k9');
      expect(await vault.readUserThemeId('user-1'), 'weekday-03-k9');
    });

    test('setTheme triggers two-way sync and persists to service and vault', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-test-1');

      await controller.setTheme('weekday-07-it', 'org-test-1');

      expect(controller.activeThemeId, 'weekday-07-it');
      expect(service.setThemeCalls, 1);
      expect(service.lastSetThemeId, 'weekday-07-it');
      expect(await vault.readUserThemeId('user-1'), 'weekday-07-it');
    });

    test('setTheme handles PT412 version conflict by adopting latest context', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-test-1');

      service.shouldThrowConflictOnce = true;
      await controller.setTheme('weekday-02-alatamasztas', 'org-test-1');

      // Megoldja az ütközést és átveszi a legfrissebb szerverállapotot
      expect(controller.activeThemeId, 'weekday-05-torzs');
      expect(controller.currentVersion, 10);
    });

    test('realtime invalidation trigger re-fetches latest theme from server', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-test-1');
      expect(controller.activeThemeId, 'weekday-01-alpin');

      // A szerveren megváltozik a téma (pl. webről módosítva)
      service.currentContext = ThemeContext(
        contractVersion: 'rp-theme-1',
        organizationId: 'org-test-1',
        activeThemeId: 'seasonal-01-karacsony',
        themeSource: 'user',
        userPreference: UserThemePreference(
          themeId: 'seasonal-01-karacsony',
          version: 5,
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );

      // Invalidation jel érkezik a Realtime csatornán
      service.emitRealtimeInvalidation();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.activeThemeId, 'seasonal-01-karacsony');
      expect(controller.currentThemeDefinition.group, 'seasonal');
    });

    test('onOrganizationChanged re-subscribes and updates org-specific theme', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-1');

      service.currentContext = ThemeContext(
        contractVersion: 'rp-theme-1',
        organizationId: 'org-2',
        activeThemeId: 'weekday-08-liaison',
        themeSource: 'organization',
      );

      await controller.onOrganizationChanged('org-2');
      expect(controller.activeThemeId, 'weekday-08-liaison');
    });

    test('onUserSignedOut cleans up subscription and resets active theme', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-1');
      await controller.setTheme('weekday-09-muszaki-mentes', 'org-1');

      await controller.onUserSignedOut();

      expect(controller.activeThemeId, 'weekday-01-alpin');
      expect(controller.contextData, isNull);
    });
  });
}
