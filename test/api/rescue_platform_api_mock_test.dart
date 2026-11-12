import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/api/mock_rescue_platform_api.dart';
import 'package:hunor_app/models/api_error.dart';

void main() {
  group('MockRescuePlatformApi – Többszervezetes és OpenAPI v0.2 tesztek', () {
    late MockRescuePlatformApi api;

    setUp(() {
      api = MockRescuePlatformApi();
    });

    test('F01: Saját profil sikeres lekérése (200 OK)', () async {
      final profile = await api.getMyProfile();
      expect(profile.user.id, MockRescuePlatformApi.mockUserId);
      expect(profile.user.email, 'mock@example.invalid');
      expect(profile.user.displayName, 'Mock Tag');
      expect(profile.version, 1);
    });

    test('F02: Cross-tenant adatizoláció – más szervezet eseménye 404 NOT_FOUND', () async {
      // Az alapértelmezett aktív szervezet: Org A (HUNOR)
      expect(api.currentOrganizationId, MockRescuePlatformApi.orgAId);

      // Org A eseménye elérhető
      final eventA = await api.getEvent(MockRescuePlatformApi.mockEventAId);
      expect(eventA.organizationId, MockRescuePlatformApi.orgAId);

      // Org B eseménye az Org A kontextusában 404 NOT_FOUND hibát ad (nem szivárog ki adat)
      expect(
        () => api.getEvent(MockRescuePlatformApi.mockEventBId),
        throwsA(
          isA<NotFoundException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'NOT_FOUND'),
        ),
      );
    });

    test('F02b: Események és riasztások listázása szigorúan az aktív szervezetre szűrt', () async {
      final events = await api.getEvents();
      expect(events.every((e) => e.organizationId == MockRescuePlatformApi.orgAId), isTrue);

      final alerts = await api.getAlerts();
      expect(alerts.every((a) => a.organizationId == MockRescuePlatformApi.orgAId), isTrue);
    });

    test('F03: Hiányzó vagy érvénytelen munkamenet – 401 UNAUTHENTICATED', () async {
      api.setAuthenticated(false);

      expect(
        () => api.getMyProfile(),
        throwsA(
          isA<UnauthorizedException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.code, 'code', 'UNAUTHENTICATED'),
        ),
      );
    });

    test('F04: Nem jóváhagyott tagság műveletkor – 403 MEMBERSHIP_NOT_APPROVED', () async {
      api.simulateRevokedMembership = true;

      expect(
        () => api.dispatchAlert(
          title: 'Teszt riasztás',
          message: 'Üzenet',
          type: 'alert',
        ),
        throwsA(
          isA<ForbiddenException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.code, 'code', 'MEMBERSHIP_NOT_APPROVED'),
        ),
      );
    });

    test('F06 & F07: Riasztási válasz idempotens újrajátszása', () async {
      const idempotencyKey = 'idempotent-test-key-123';

      final res1 = await api.setMyAlertResponse(
        alertId: MockRescuePlatformApi.mockAlertAId,
        response: 'going',
        idempotencyKey: idempotencyKey,
      );
      expect(res1.response, 'going');

      // Azonos kérés újraküldése ugyanazzal a kulccsal -> idempotens visszatérés
      final res2 = await api.setMyAlertResponse(
        alertId: MockRescuePlatformApi.mockAlertAId,
        response: 'going',
        idempotencyKey: idempotencyKey,
      );
      expect(res2.response, 'going');
    });

    test('F08: Idempotencia konfliktus eltérő törzzsel – 409 IDEMPOTENCY_CONFLICT', () async {
      const idempotencyKey = 'idempotent-conflict-key-456';

      await api.setMyAlertResponse(
        alertId: MockRescuePlatformApi.mockAlertAId,
        response: 'going',
        idempotencyKey: idempotencyKey,
      );

      // Ugyanaz a kulcs, de megváltozott válasz -> 409
      expect(
        () => api.setMyAlertResponse(
          alertId: MockRescuePlatformApi.mockAlertAId,
          response: 'not_going',
          idempotencyKey: idempotencyKey,
        ),
        throwsA(
          isA<ConflictException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.code, 'code', 'IDEMPOTENCY_CONFLICT'),
        ),
      );
    });

    test('F09: Válaszadás lejárt riasztásra – 409 ALERT_EXPIRED', () async {
      expect(
        () => api.setMyAlertResponse(
          alertId: MockRescuePlatformApi.mockAlertExpiredId,
          response: 'going',
        ),
        throwsA(
          isA<ConflictException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.code, 'code', 'ALERT_EXPIRED'),
        ),
      );
    });

    test('F12: Inkompatibilis platform és push provider – 422 INVALID_DEVICE_PROVIDER', () async {
      // Androidon APNs nem támogatott
      expect(
        () => api.registerMyInstallation(
          installationId: MockRescuePlatformApi.mockInstallationId,
          platform: 'android',
          provider: 'apns',
          token: 'mock-token',
        ),
        throwsA(
          isA<UnprocessableEntityException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.code, 'code', 'INVALID_DEVICE_PROVIDER'),
        ),
      );
    });

    test('F15: Érmeegyenleg (RC balance) lekérdezése', () async {
      final balance = await api.getCoinBalance();
      expect(balance.organizationId, MockRescuePlatformApi.orgAId);
      expect(balance.unit, 'RC');
      expect(balance.balance, 120);
    });

    test('F16: Kijelentkezés (revokeCurrentSession) – Session és cache törlés', () async {
      await api.revokeCurrentSession();
      expect(api.isAuthenticated, isFalse);
      expect(api.currentOrganizationId, isNull);
      expect(api.isCacheCleared, isTrue);

      expect(() => api.getMyProfile(), throwsA(isA<UnauthorizedException>()));
    });

    test('F18: Szervezetváltás (Tenant Switch) – Gyorsítótár ürítés és új adatszűrés', () async {
      expect(api.currentOrganizationId, MockRescuePlatformApi.orgAId);

      // Váltás Org B-re (Barlangi Mentőszolgálat)
      await api.switchOrganization(MockRescuePlatformApi.orgBId);
      expect(api.currentOrganizationId, MockRescuePlatformApi.orgBId);

      // Most már Org B eseményei láthatók
      final eventB = await api.getEvent(MockRescuePlatformApi.mockEventBId);
      expect(eventB.organizationId, MockRescuePlatformApi.orgBId);

      // És Org A eseménye most már 404 NOT_FOUND!
      expect(
        () => api.getEvent(MockRescuePlatformApi.mockEventAId),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
