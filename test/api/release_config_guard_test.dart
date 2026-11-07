import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/api/mock_rescue_platform_api.dart';
import 'package:hunor_app/api/staging_api.dart';
import 'package:hunor_app/main.dart';

void main() {
  group('Release API Guard és Konfigurációs Biztonsági Tesztek', () {
    test('Mock API mód sikeresen példányosít fejlesztői módban (isRelease: false)', () {
      final api = createConfiguredApi(
        mode: 'mock',
        baseUrl: '',
        isRelease: false,
      );
      expect(api, isA<MockRescuePlatformApi>());
    });

    test('Production Release build esetén a Mock API mód StateError hibát dob', () {
      expect(
        () => createConfiguredApi(
          mode: 'mock',
          baseUrl: '',
          isRelease: true,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('BIZTONSÁGI HIBA: Production Release build nem futtatható Mock API módban!'),
          ),
        ),
      );
    });

    test('Staging mód jóváhagyott végponttal sikeresen StagingApi adaptert ad vissza', () {
      final api = createConfiguredApi(
        mode: 'staging',
        baseUrl: stagingBase,
        isRelease: true,
      );
      expect(api, isA<StagingApi>());
    });

    test('Production mód üres baseUrl esetén azonnal StateError-ral áll le', () {
      expect(
        () => createConfiguredApi(
          mode: 'production',
          baseUrl: '',
          isRelease: true,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('BIZTONSÁGI HIBA: Production API módban a RESCUE_API_BASE_URL nem lehet üres!'),
          ),
        ),
      );
    });

    test('Production mód hiányzó/nem jóváhagyott adapter esetén azonnal leáll és SOHA nem ad mock fallbacket', () {
      expect(
        () => createConfiguredApi(
          mode: 'production',
          baseUrl: 'https://embicteneumubwlqqfik.supabase.co/functions/v1/rescue-platform-production/v1',
          isRelease: true,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Mock vagy teszt adapter fallback production módban szigorúan tilos!'),
          ),
        ),
      );
    });

    test('Érvénytelen API mód esetén azonnali StateError keletkezik', () {
      expect(
        () => createConfiguredApi(
          mode: 'unsupported_test_mode',
          baseUrl: '',
          isRelease: false,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Invalid API mode: unsupported_test_mode'),
          ),
        ),
      );
    });

    test('ThemeService választó production módban biztonságosan leáll fallback helyett', () {
      final mockApi = MockRescuePlatformApi();
      expect(
        () => createConfiguredThemeService(
          mode: 'production',
          api: mockApi,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('BIZTONSÁGI HIBA: Production ThemeService adapter nincs konfigurálva'),
          ),
        ),
      );
    });
  });
}
