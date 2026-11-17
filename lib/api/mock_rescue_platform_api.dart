import '../models/api_error.dart';
import '../models/coin_balance.dart';
import '../models/event_participation.dart';
import '../models/installation.dart';
import '../models/organization.dart';
import '../models/rescue_alert.dart';
import '../models/rescue_event.dart';
import '../models/rescue_news.dart';
import '../models/user_profile.dart';
import 'rescue_platform_api.dart';

/// MockRescuePlatformApi
/// A Rescue Platform OpenAPI v0.2 specifikáció és a flutter-api-v02-mock-fixtures.json
/// alapján készült mock megvalósítás offline fejlesztéshez és teszteléshez.
/// Éles Supabase hívást nem végez, szigorú szervezeti izolációt és hibakezelést biztosít.
class MockRescuePlatformApi implements RescuePlatformApi {
  // --- Azonosítók a mock fixtures alapján ---
  static const String orgAId = '11111111-1111-4111-8111-111111111111';
  static const String orgBId = '22222222-2222-4222-8222-222222222222';
  static const String mockUserId = '33333333-3333-4333-8333-333333333333';
  static const String membershipAId = '44444444-4444-4444-8444-444444444444';
  static const String membershipBId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  static const String mockEventAId = '55555555-5555-4555-8555-555555555555';
  static const String mockEventBId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
  static const String mockAlertAId = '66666666-6666-4666-8666-666666666666';
  static const String mockAlertExpiredId = '66666666-6666-4666-8666-999999999999';
  static const String mockAlertBId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
  static const String mockInstallationId = '77777777-7777-4777-8777-777777777777';

  // --- Belső állapot ---
  bool _authenticated = true;
  String? _currentOrganizationId = orgAId;
  bool _cacheCleared = false;

  // Tesztelési vezérlők
  bool simulateRevokedMembership = false;
  bool simulateReplacedInvitation = false;

  // Idempotencia nyilvántartás
  final Map<String, dynamic> _idempotentKeys = {};

  // Szervezeti gyorsítótár
  final Map<String, dynamic> _tenantCache = {};

  @override
  String? get currentOrganizationId => _currentOrganizationId;

  @override
  bool get isAuthenticated => _authenticated;

  bool get isCacheCleared => _cacheCleared;

  // --- Mock Adatbázis ---
  final List<Organization> _organizations = [
    const Organization(
      id: orgAId,
      name: 'HUNOR Mentőszervezet',
      code: 'HUNOR',
      description: 'Hivatásos Nehéz Kutató-Mentő Mentőszervezet',
      active: true,
    ),
    const Organization(
      id: orgBId,
      name: 'Barlangi Mentőszolgálat',
      code: 'BMSZ',
      description: 'Önkéntes barlangi és hegyi mentés',
      active: true,
    ),
  ];

  late final Map<String, Membership> _memberships = {
    orgAId: const Membership(
      id: membershipAId,
      organizationId: orgAId,
      userId: mockUserId,
      displayName: 'Mock Tag',
      membershipStatus: MembershipStatus.approved,
      positions: ['technical_rescuer'],
      skills: ['USAR', 'rope_access'],
      alertable: true,
      permissions: ['organization.read', 'alerts.read', 'alerts.respond', 'events.read'],
      permissionsVersion: 1,
      version: 1,
    ),
    orgBId: const Membership(
      id: membershipBId,
      organizationId: orgBId,
      userId: mockUserId,
      displayName: 'Mock Tag',
      membershipStatus: MembershipStatus.approved,
      positions: [],
      skills: ['cave_rescue'],
      alertable: false,
      permissions: ['organization.read'],
      permissionsVersion: 1,
      version: 1,
    ),
  };

  static DateTime get _today => DateTime.now();

  final List<RescueEvent> _events = [
    RescueEvent(
      id: mockEventAId,
      organizationId: orgAId,
      title: 'HUNOR Tavaszi Gyakorlat',
      description: 'Romkutatási és kötéltechnikai felkészítés.',
      location: 'Hajdúszoboszló Gyakorlótér',
      startsAt: DateTime(_today.year, _today.month, _today.day, 8, 0),
      endsAt: DateTime(_today.year, _today.month, _today.day, 18, 0),
      version: 1,
    ),
    RescueEvent(
      id: mockEventBId,
      organizationId: orgBId,
      title: 'BMSZ Barlangi Kötélgyakorlat',
      description: 'Szűk járatú hordágyas mentés.',
      location: 'Pál-völgyi barlangrendszer',
      startsAt: DateTime(_today.year, _today.month, _today.day, 9, 0),
      endsAt: DateTime(_today.year, _today.month, _today.day, 17, 0),
      version: 1,
    ),
  ];

  final List<RescueAlert> _alerts = [
    RescueAlert(
      id: mockAlertAId,
      organizationId: orgAId,
      title: 'Földrengési Riasztás – Előkészület',
      message: 'Földrengés a célterületen. Állomány készenlétbe helyezése.',
      type: 'alert',
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      version: 1,
    ),
    RescueAlert(
      id: mockAlertExpiredId,
      organizationId: orgAId,
      title: 'Lejárt Gyakorlati Értesítés',
      message: 'Ez a riasztási időablak már lezárult.',
      type: 'exercise',
      status: 'expired',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      version: 1,
    ),
    RescueAlert(
      id: mockAlertBId,
      organizationId: orgBId,
      title: 'BMSZ Barlangi Készenlét',
      message: 'Készenlét elrendelése barlangi baleset miatt.',
      type: 'standby',
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
      version: 1,
    ),
  ];

  final Map<String, AlertResponse> _alertResponses = {};

  // --- Segédfüggvények a hitelesítés és jogosultság ellenőrzésére ---
  void _checkAuth() {
    if (!_authenticated) {
      throw const UnauthorizedException(
        code: 'UNAUTHENTICATED',
        message: 'Jelentkezz be újra.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }
  }

  void _checkActiveTenant() {
    _checkAuth();
    if (_currentOrganizationId == null) {
      throw const ForbiddenException(
        code: 'NO_ACTIVE_ORGANIZATION',
        message: 'Nincs aktív szervezet kiválasztva.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }
  }

  // --- API Megvalósítások ---

  @override
  Future<UserProfile> getMyProfile() async {
    _checkAuth();
    return const UserProfile(
      user: User(
        id: mockUserId,
        email: 'mock@example.invalid',
        displayName: 'Mock Tag',
      ),
      contactPhone: null,
      version: 1,
    );
  }

  @override
  Future<void> revokeCurrentSession() async {
    _authenticated = false;
    clearTenantCache();
    _currentOrganizationId = null;
  }

  @override
  Future<void> requestAccountDeletion({required String reason}) async {
    _checkAuth();
    // Szimulált szerveroldali fióktörlési kérelem rögzítés és session azonnali visszavonás
    _authenticated = false;
    clearTenantCache();
    _currentOrganizationId = null;
  }

  @override
  Future<List<Organization>> getMyOrganizations() async {
    _checkAuth();
    return List.unmodifiable(_organizations);
  }

  @override
  Future<Membership> getMyOrganizationMembership(String organizationId) async {
    _checkAuth();
    final membership = _memberships[organizationId];
    if (membership == null) {
      throw const NotFoundException(
        code: 'NOT_FOUND',
        message: 'Nem vagy tagja a megadott szervezetnek.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }
    return membership;
  }

  @override
  Future<void> switchOrganization(String organizationId) async {
    _checkAuth();
    if (!_organizations.any((org) => org.id == organizationId)) {
      throw const NotFoundException(
        code: 'NOT_FOUND',
        message: 'A kért szervezet nem létezik.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }

    final membership = _memberships[organizationId];
    if (membership == null) {
      throw const ForbiddenException(
        code: 'FORBIDDEN',
        message: 'Nincs tagságod ebben a szervezetben.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }

    // F18: A váltás előtt a korábbi szervezet gyorsítótárát kötelező üríteni!
    clearTenantCache();
    _currentOrganizationId = organizationId;
    _cacheCleared = false;
  }

  @override
  Future<List<RescueEvent>> getEvents() async {
    _checkActiveTenant();
    // Cross-tenant izoláció: KIZÁRÓLAG az aktív szervezet eseményei!
    return _events.where((e) => e.organizationId == _currentOrganizationId).toList();
  }

  @override
  Future<RescueEvent> getEvent(String eventId) async {
    _checkActiveTenant();
    final event = _events.where((e) => e.id == eventId).firstOrNull;
    if (event == null || event.organizationId != _currentOrganizationId) {
      // F02: Másik szervezet eseménye 404 NOT_FOUND hibát ad (nem szivárogtatunk információt)
      throw const NotFoundException(
        code: 'NOT_FOUND',
        message: 'Az erőforrás nem található.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }
    return event;
  }

  @override
  Future<List<RescueAlert>> getAlerts() async {
    _checkActiveTenant();
    // Cross-tenant izoláció: KIZÁRÓLAG az aktív szervezet riasztásai!
    return _alerts.where((a) => a.organizationId == _currentOrganizationId).toList();
  }

  @override
  Future<RescueAlert> getAlert(String alertId) async {
    _checkActiveTenant();
    final alert = _alerts.where((a) => a.id == alertId).firstOrNull;
    if (alert == null || alert.organizationId != _currentOrganizationId) {
      throw const NotFoundException(
        code: 'NOT_FOUND',
        message: 'A riasztás nem található.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }
    return alert;
  }

  @override
  Future<RescueAlert> dispatchAlert({
    required String title,
    required String message,
    required String type,
    DateTime? expiresAt,
  }) async {
    _checkActiveTenant();
    final membership = _memberships[_currentOrganizationId];
    if (simulateRevokedMembership || membership == null || !membership.isApproved) {
      // F04: Nem jóváhagyott / visszavont tagság esetén 403 Forbidden
      throw const ForbiddenException(
        code: 'MEMBERSHIP_NOT_APPROVED',
        message: 'Jóváhagyott tagság szükséges.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }

    final newAlert = RescueAlert(
      id: 'alert-${DateTime.now().millisecondsSinceEpoch}',
      organizationId: _currentOrganizationId!,
      title: title,
      message: message,
      type: type,
      status: 'active',
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      version: 1,
    );
    _alerts.add(newAlert);
    return newAlert;
  }

  @override
  Future<AlertResponse> setMyAlertResponse({
    required String alertId,
    required String response,
    int? expectedVersion,
    String? idempotencyKey,
  }) async {
    _checkActiveTenant();
    final alert = await getAlert(alertId);

    // F09: Lejárt riasztásra válaszadás -> 409 ALERT_EXPIRED
    if (alert.isExpired) {
      throw const ConflictException(
        code: 'ALERT_EXPIRED',
        message: 'A riasztás lejárt.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }

    // F05: Verziókonfliktus ellenőrzése
    if (expectedVersion != null && expectedVersion != alert.version) {
      throw const PreconditionFailedException(
        code: 'VERSION_CONFLICT',
        message: 'Az adat megváltozott.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }

    // F07 és F08: Idempotencia ellenőrzése
    if (idempotencyKey != null) {
      if (_idempotentKeys.containsKey(idempotencyKey)) {
        final previous = _idempotentKeys[idempotencyKey];
        if (previous['response'] != response || previous['alert_id'] != alertId) {
          // F08: Ugyanaz a kulcs eltérő törzzsel -> 409 IDEMPOTENCY_CONFLICT
          throw const ConflictException(
            code: 'IDEMPOTENCY_CONFLICT',
            message: 'A kérésazonosító másik kéréshez tartozik.',
            requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          );
        }
        // F07: Azonos kérés újrajátszása -> visszatér az eredeti válasszal
        return previous['result'] as AlertResponse;
      }
    }

    final membership = _memberships[_currentOrganizationId]!;
    final alertResponse = AlertResponse(
      alertId: alertId,
      membershipId: membership.id,
      response: response,
      respondedAt: DateTime.now(),
      version: alert.version,
    );

    _alertResponses[alertId] = alertResponse;
    if (idempotencyKey != null) {
      _idempotentKeys[idempotencyKey] = {
        'alert_id': alertId,
        'response': response,
        'result': alertResponse,
      };
    }

    return alertResponse;
  }

  @override
  Future<void> acknowledgeAlert(String alertId, {String? idempotencyKey}) async {
    _checkActiveTenant();
    // F10: Helyettesített meghívás esetén 409 INVITATION_REPLACED
    if (simulateReplacedInvitation) {
      throw const ConflictException(
        code: 'INVITATION_REPLACED',
        message: 'A meghívás helyettesítve lett.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }
  }

  @override
  Future<Installation> registerMyInstallation({
    required String installationId,
    required String platform,
    required String provider,
    required String token,
    String? label,
    String? environment,
  }) async {
    _checkAuth();

    // F12: Inkompatibilis platform és provider szűrése -> 422 INVALID_DEVICE_PROVIDER
    if ((platform == 'android' && provider == 'apns') ||
        (platform == 'ios' && provider != 'apns' && provider != 'fcm')) {
      throw const UnprocessableEntityException(
        code: 'INVALID_DEVICE_PROVIDER',
        message: 'A platform és a provider nem kompatibilis.',
        requestId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
    }

    // F11: Sikeres regisztráció
    return Installation(
      id: installationId,
      platform: platform,
      provider: provider,
      environment: environment ?? 'development',
      label: label ?? 'Mock Device',
      active: true,
      version: 1,
    );
  }

  @override
  Future<Installation> updateMyInstallation({
    required String installationId,
    required String provider,
    required String token,
  }) async {
    _checkAuth();
    // F17: Token frissítés (verzió növelése)
    return Installation(
      id: installationId,
      platform: 'ios',
      provider: provider,
      environment: 'development',
      label: 'Mock Device',
      active: true,
      version: 2,
    );
  }

  @override
  Future<DeviceReceipt> confirmDeviceReceipt({
    required String deliveryId,
    required String receiptToken,
  }) async {
    // F13: Készülék átvételi igazolás
    return DeviceReceipt(
      received: true,
      receivedAt: DateTime.now(),
    );
  }

  @override
  Future<CoinBalance> getCoinBalance() async {
    _checkActiveTenant();
    final membership = _memberships[_currentOrganizationId]!;
    // F15: Érmeegyenleg
    return CoinBalance(
      organizationId: _currentOrganizationId!,
      membershipId: membership.id,
      unit: 'RC',
      balance: _currentOrganizationId == orgAId ? 120 : 0,
      asOf: DateTime.now(),
      ledgerVersion: 'fixture-1',
    );
  }

  // CODEX-017 / CODEX-018 Mock Adattárak
  final Map<String, EventParticipation> _participations = {};
  final Map<String, EventRegistrationInfo> _registrationInfos = {};
  final List<RescueNewsItem> _mockNews = [
    RescueNewsItem(
      id: 'news-001',
      organizationId: orgAId,
      title: 'Téli felkészülési gyakorlat a Mátrában',
      summary: 'A HUNOR nehézkutató egység 3 napos téli bevetési szimulációt tart.',
      content: 'A gyakorlat célja a lavina- és hegyimentési eljárások összehangolása extrém időjárási körülmények között. Minden résztvevőtől elvárt a teljes téli védőfelszerelés megléte.',
      authorName: 'Műveleti Parancsnokság',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      audience: NewsAudience.members,
      isPinned: true,
      tags: const ['Gyakorlat', 'HUNOR', 'Tél'],
    ),
    RescueNewsItem(
      id: 'news-002',
      organizationId: orgAId,
      title: 'Új akkumulátoros feszítő-vágó készletek érkeztek',
      summary: 'Átvehetők az új generációs műszaki mentőeszközök a logisztikai raktárban.',
      content: 'A legmodernebb hidraulikus feszítő-vágó szerszámok megérkeztek a bázisra. Kérjük a szerparancsnokokat, hogy egyeztessenek az eszközök beosztásáról és átvételéről.',
      authorName: 'Logisztikai Csoport',
      publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      audience: NewsAudience.all,
      tags: const ['Eszközök', 'Logisztika'],
    ),
    RescueNewsItem(
      id: 'news-003',
      organizationId: orgBId,
      title: 'Barlangi mentőorvosi továbbképzés',
      summary: 'Speciális hipotermiás ellátás barlangi környezetben.',
      content: 'A BMSZ orvoscsoportja belső továbbképzést szervez az aggregátorról működtetett melegítőrendszerek használatáról mélységi mentések során.',
      authorName: 'BMSZ Egészségügy',
      publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      audience: NewsAudience.members,
      tags: const ['Orvosi', 'BMSZ'],
    ),
  ];

  @override
  Future<EventRegistrationInfo> getEventRegistrationInfo(String eventId) async {
    _checkActiveTenant();
    return _registrationInfos[eventId] ??
        EventRegistrationInfo(
          eventId: eventId,
          organizationId: _currentOrganizationId!,
          maxCapacity: 20,
          currentGoingCount: 8,
          registrationDeadline: DateTime.now().add(const Duration(days: 7)),
          cancellationDeadline: DateTime.now().add(const Duration(days: 6)),
          rulesVersion: 1,
          isEligible: true,
        );
  }

  @override
  Future<EventParticipation> getMyEventParticipation(String eventId) async {
    _checkActiveTenant();
    final membership = _memberships[_currentOrganizationId]!;
    return _participations['${_currentOrganizationId}_$eventId'] ??
        EventParticipation(
          organizationId: _currentOrganizationId!,
          eventId: eventId,
          membershipId: membership.id,
          response: null,
          version: 0,
        );
  }

  @override
  Future<EventParticipation> setMyEventParticipation({
    required String eventId,
    required EventParticipationStatus response,
    required int expectedVersion,
    String? idempotencyKey,
  }) async {
    _checkActiveTenant();
    final membership = _memberships[_currentOrganizationId]!;
    final key = '${_currentOrganizationId}_$eventId';
    final current = _participations[key] ??
        EventParticipation(
          organizationId: _currentOrganizationId!,
          eventId: eventId,
          membershipId: membership.id,
          response: null,
          version: 0,
        );

    if (expectedVersion != current.version) {
      throw const PreconditionFailedException(
        code: 'VERSION_CONFLICT',
        message: 'A részvételi állapot időközben megváltozott a szerveren (412).',
      );
    }

    final updated = EventParticipation(
      organizationId: _currentOrganizationId!,
      eventId: eventId,
      membershipId: membership.id,
      response: response,
      respondedAt: DateTime.now(),
      version: current.version + 1,
    );
    _participations[key] = updated;
    return updated;
  }

  @override
  Future<List<RescueNewsItem>> getNews({int limit = 20, String? cursor}) async {
    _checkActiveTenant();
    return _mockNews
        .where((n) => n.organizationId == _currentOrganizationId)
        .take(limit)
        .toList();
  }

  @override
  Future<RescueNewsItem> getNewsItem(String newsId) async {
    _checkActiveTenant();
    final item = _mockNews.where((n) => n.organizationId == _currentOrganizationId && n.id == newsId).firstOrNull;
    if (item == null) {
      throw const NotFoundException(message: 'A kért hír nem található ebben a szervezetben.');
    }
    return item;
  }

  @override
  void clearTenantCache() {
    _tenantCache.clear();
    _alertResponses.clear();
    _participations.clear();
    _idempotentKeys.clear();
    _cacheCleared = true;
  }

  // --- Tesztelési állapotváltók ---
  void setAuthenticated(bool authenticated) {
    _authenticated = authenticated;
  }
}
