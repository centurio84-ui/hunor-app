import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/api/supabase_rescue_platform_api.dart';
import 'package:hunor_app/main.dart';
import 'package:hunor_app/models/event_participation.dart';
import 'package:hunor_app/services/theme_service.dart';

void main() {
  group('SupabaseRescuePlatformApi Konfigurációs és Modell Tesztek', () {
    test('createConfiguredApi supabase módban SupabaseRescuePlatformApi-t hoz létre', () {
      final api = createConfiguredApi(
        mode: 'supabase',
        baseUrl: '',
        isRelease: false,
      );
      expect(api, isA<SupabaseRescuePlatformApi>());
      expect(api.currentOrganizationId, equals('org-hunor'));
      expect(api.isAuthenticated, isFalse);
    });

    test('createConfiguredThemeService supabase módban SupabaseThemeService-t hoz létre', () {
      final api = createConfiguredApi(
        mode: 'supabase',
        baseUrl: '',
        isRelease: false,
      );
      final themeService = createConfiguredThemeService(
        mode: 'supabase',
        api: api,
      );
      expect(themeService, isA<SupabaseThemeService>());
    });

    test('Eseményjelentkezés státusz DTO oda-vissza konverzió', () {
      expect(EventParticipationStatusX.fromString('going'), equals(EventParticipationStatus.going));
      expect(EventParticipationStatusX.fromString('not_going'), equals(EventParticipationStatus.notGoing));
      expect(EventParticipationStatus.going.value, equals('going'));
      expect(EventParticipationStatus.notGoing.value, equals('not_going'));
    });
  });
}
