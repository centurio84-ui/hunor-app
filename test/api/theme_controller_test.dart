import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/models/api_error.dart';
import 'package:hunor_app/models/theme_config.dart';
import 'package:hunor_app/services/theme_controller.dart';
import 'package:hunor_app/services/theme_service.dart';
import 'package:hunor_app/services/theme_vault.dart';

class TestThemeService implements ThemeService {
  ThemeContext _context;
  final StreamController<void> _signalsController = StreamController<void>.broadcast();
  int setMyThemeCalls = 0;
  String? lastSetThemeId;
  bool throwConflictOnce = false;

  TestThemeService({ThemeContext? initialContext})
      : _context = initialContext ??
            const ThemeContext(
              contractVersion: 'rp-theme-1',
              organizationId: 'org-test-1',
              effectiveThemeId: RescueThemeRegistry.defaultThemeId,
              source: 'global',
              organizationVersion: 1,
              allowPersonal: true,
              globalThemeId: RescueThemeRegistry.defaultThemeId,
              globalVersion: 1,
              userVersion: 0,
            );

  void setServerContext(ThemeContext context) {
    _context = context;
  }

  void triggerSignal() {
    _signalsController.add(null);
  }

  @override
  Future<ThemeContext> getThemeContext(String organizationId) async {
    return _context;
  }

  @override
  Future<List<ThemeCatalogItem>> getCatalog() async {
    return RescueThemeRegistry.allThemes
        .map(
          (d) => ThemeCatalogItem(
            id: d.id,
            name: d.name,
            category: d.isSeasonal ? 'seasonal' : 'weekday',
            description: d.description,
            primaryColor: d.primaryColor,
          ),
        )
        .toList();
  }

  @override
  Future<ThemeContext> setMyTheme({
    required String organizationId,
    required String? themeId,
    required int expectedVersion,
  }) async {
    setMyThemeCalls++;
    lastSetThemeId = themeId;

    if (throwConflictOnce) {
      throwConflictOnce = false;
      throw const PreconditionFailedException(
        code: 'PT412',
        message: 'A téma verziója időközben megváltozott a szerveren (PT412).',
      );
    }

    _context = _context.copyWith(
      effectiveThemeId: themeId ?? _context.globalThemeId,
      source: 'user',
      userThemeId: themeId,
      userVersion: expectedVersion + 1,
    );
    return _context;
  }

  @override
  Stream<void> subscribeToThemeSignals({
    required String organizationId,
    required String userId,
  }) {
    return _signalsController.stream;
  }

  @override
  Future<void> unsubscribe() async {}

  void dispose() {
    _signalsController.close();
  }
}

void main() {
  group('ThemeController', () {
    late InMemoryThemeVault vault;
    late TestThemeService service;
    late ThemeController controller;

    setUp(() {
      vault = InMemoryThemeVault();
      service = TestThemeService();
      controller = ThemeController(themeService: service, themeVault: vault);
    });

    tearDown(() {
      controller.dispose();
      service.dispose();
    });

    test('initializes immediately from local cache (flash-free)', () async {
      await vault.writeTheme('weekday-04-medic');
      await controller.initialize();

      expect(controller.currentThemeId, 'weekday-04-medic');
      expect(controller.currentDefinition.name, 'Medic');
      expect(controller.isLoading, isFalse);
    });

    test('onUserSignedIn loads server context and updates local cache', () async {
      await controller.initialize();
      service.setServerContext(const ThemeContext(
        contractVersion: 'rp-theme-1',
        organizationId: 'org-test-1',
        effectiveThemeId: 'weekday-03-k9',
        source: 'organization',
        organizationVersion: 2,
        allowPersonal: true,
        globalThemeId: 'weekday-01-alpin',
        globalVersion: 1,
        userVersion: 0,
      ));

      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-test-1');

      expect(controller.currentThemeId, 'weekday-03-k9');
      expect(controller.themeContext?.source, 'organization');
      expect(await vault.readTheme(), 'weekday-03-k9');
      expect(await vault.readTheme(userId: 'user-1', organizationId: 'org-test-1'), 'weekday-03-k9');
      expect(controller.isSubscribed, isTrue);
    });

    test('setTheme triggers two-way sync and persists to service and vault', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-test-1');

      await controller.setTheme('weekday-07-it');

      expect(controller.currentThemeId, 'weekday-07-it');
      expect(service.setMyThemeCalls, 1);
      expect(service.lastSetThemeId, 'weekday-07-it');
      expect(await vault.readTheme(userId: 'user-1', organizationId: 'org-test-1'), 'weekday-07-it');
    });

    test('setTheme handles PT412 version conflict by resyncing from server', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-test-1');

      service.throwConflictOnce = true;
      // Közben a szerver más témára váltott
      service.setServerContext(const ThemeContext(
        contractVersion: 'rp-theme-1',
        organizationId: 'org-test-1',
        effectiveThemeId: 'weekday-05-torzs',
        source: 'user',
        organizationVersion: 2,
        allowPersonal: true,
        globalThemeId: 'weekday-01-alpin',
        globalVersion: 1,
        userVersion: 5,
      ));

      await controller.setTheme('weekday-02-alatamasztas');

      // Ütközés után átvette a legfrissebb szerverállapotot
      expect(controller.currentThemeId, 'weekday-05-torzs');
      expect(controller.themeContext?.userVersion, 5);
    });

    test('realtime invalidation signal re-fetches latest theme from server', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-test-1');
      expect(controller.currentThemeId, 'weekday-01-alpin');

      // A weben a felhasználó átváltja karácsonyi témára
      service.setServerContext(const ThemeContext(
        contractVersion: 'rp-theme-1',
        organizationId: 'org-test-1',
        effectiveThemeId: 'seasonal-01-karacsony',
        source: 'user',
        organizationVersion: 2,
        allowPersonal: true,
        globalThemeId: 'weekday-01-alpin',
        globalVersion: 1,
        userVersion: 2,
      ));

      // Realtime signal invalidáció érkezik
      service.triggerSignal();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.currentThemeId, 'seasonal-01-karacsony');
      expect(controller.currentDefinition.isSeasonal, isTrue);
    });

    test('onOrganizationChanged re-subscribes and updates org-specific theme', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-1');

      service.setServerContext(const ThemeContext(
        contractVersion: 'rp-theme-1',
        organizationId: 'org-2',
        effectiveThemeId: 'weekday-08-liaison',
        source: 'organization',
        organizationVersion: 3,
        allowPersonal: true,
        globalThemeId: 'weekday-01-alpin',
        globalVersion: 1,
        userVersion: 0,
      ));

      await controller.onOrganizationChanged('org-2');
      expect(controller.currentThemeId, 'weekday-08-liaison');
    });

    test('onUserSignedOut cleans up subscription and resets active theme', () async {
      await controller.initialize();
      await controller.onUserSignedIn(userId: 'user-1', organizationId: 'org-1');
      await controller.setTheme('weekday-09-muszaki-mentes');

      await controller.onUserSignedOut();

      expect(controller.currentThemeId, 'weekday-01-alpin');
      expect(controller.themeContext, isNull);
      expect(controller.isSubscribed, isFalse);
    });
  });
}
