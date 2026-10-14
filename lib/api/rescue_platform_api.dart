import '../models/api_error.dart';
import '../models/coin_balance.dart';
import '../models/installation.dart';
import '../models/organization.dart';
import '../models/rescue_alert.dart';
import '../models/rescue_event.dart';
import '../models/user_profile.dart';

/// Típusos API interfész a Rescue Platform OpenAPI v0.2 specifikációja alapján.
/// Támogatja a többszervezetes modellt, a szervezeti izolációt, a hibakezelést és a cache-tisztítást.
abstract class RescuePlatformApi {
  /// Az aktuálisan aktív szervezet azonosítója.
  String? get currentOrganizationId;

  /// Hitelesített-e a munkamenet.
  bool get isAuthenticated;

  // --- Felhasználói profil és munkamenet ---
  Future<UserProfile> getMyProfile();
  Future<void> revokeCurrentSession();

  // --- Többszervezetes kezelés (Multi-tenancy) ---
  Future<List<Organization>> getMyOrganizations();
  Future<Membership> getMyOrganizationMembership(String organizationId);
  Future<void> switchOrganization(String organizationId);

  // --- Események (Events) ---
  Future<List<RescueEvent>> getEvents();
  Future<RescueEvent> getEvent(String eventId);

  // --- Riasztások (Alerts) ---
  Future<List<RescueAlert>> getAlerts();
  Future<RescueAlert> getAlert(String alertId);
  Future<RescueAlert> dispatchAlert({
    required String title,
    required String message,
    required String type,
    DateTime? expiresAt,
  });
  Future<AlertResponse> setMyAlertResponse({
    required String alertId,
    required String response,
    int? expectedVersion,
    String? idempotencyKey,
  });
  Future<void> acknowledgeAlert(String alertId, {String? idempotencyKey});

  // --- Eszközök és értesítések (Installations) ---
  Future<Installation> registerMyInstallation({
    required String installationId,
    required String platform,
    required String provider,
    required String token,
    String? label,
    String? environment,
  });
  Future<Installation> updateMyInstallation({
    required String installationId,
    required String provider,
    required String token,
  });
  Future<DeviceReceipt> confirmDeviceReceipt({
    required String deliveryId,
    required String receiptToken,
  });

  // --- Elismerések / Érmék (Coin balance) ---
  Future<CoinBalance> getCoinBalance();

  // --- Szervezeti gyorsítótár és állapotkezelés ---
  void clearTenantCache();
}
