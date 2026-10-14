import 'package:flutter/foundation.dart';
import '../api/mock_rescue_platform_api.dart';
import '../api/rescue_platform_api.dart';
import '../models/coin_balance.dart';
import '../models/member.dart';
import '../models/organization.dart';
import '../models/rescue_alert.dart';
import '../models/rescue_event.dart';
import '../models/user_profile.dart';

enum MemberRole { member, admin }

/// AppStore – Központi állapotkezelő a Rescue Platform Flutter mobilalkalmazáshoz.
/// Támogatja a RescuePlatformApi és MockRescuePlatformApi használatát,
/// megvalósítja a többszervezetes adatizolációt és a szervezetváltási cache-ürítést.
class AppStore extends ChangeNotifier {
  final RescuePlatformApi api;

  AppStore({RescuePlatformApi? api}) : api = api ?? MockRescuePlatformApi();

  UserProfile? currentUserProfile;
  Member? currentUser;
  Organization? currentOrganization;
  Membership? currentMembership;
  List<Organization> availableOrganizations = [];
  List<RescueEvent> events = [];
  List<RescueAlert> alerts = [];
  CoinBalance? coinBalance;

  Map<String, String> eventResponses = {};
  Map<String, String> alertResponses = {};
  MemberRole currentUserRole = MemberRole.member;

  bool isAuthenticated = false;
  bool isLoading = false;
  bool initialized = false;
  String? errorMessage;

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      isAuthenticated = api.isAuthenticated;
      if (isAuthenticated) {
        await loadData();
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (api is MockRescuePlatformApi) {
        (api as MockRescuePlatformApi).setAuthenticated(true);
      }
      isAuthenticated = true;
      await loadData();
    } catch (e) {
      errorMessage = e.toString();
      isAuthenticated = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    isLoading = true;
    notifyListeners();

    try {
      await api.revokeCurrentSession();
      // Kijelentkezéskor kötelező az összes szervezeti adat ürítése
      _clearLocalData();
      isAuthenticated = false;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _clearLocalData() {
    currentUserProfile = null;
    currentUser = null;
    currentOrganization = null;
    currentMembership = null;
    availableOrganizations = [];
    events = [];
    alerts = [];
    coinBalance = null;
    eventResponses.clear();
    alertResponses.clear();
  }

  Future<void> loadData() async {
    if (!api.isAuthenticated) {
      isAuthenticated = false;
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // 1. Felhasználói profil
      currentUserProfile = await api.getMyProfile();

      // 2. Elérhető szervezetek
      availableOrganizations = await api.getMyOrganizations();

      // 3. Aktuális szervezet beállítása
      final activeOrgId = api.currentOrganizationId ?? availableOrganizations.firstOrNull?.id;
      if (activeOrgId != null) {
        currentOrganization = availableOrganizations.where((o) => o.id == activeOrgId).firstOrNull;
        if (currentOrganization != null) {
          try {
            currentMembership = await api.getMyOrganizationMembership(activeOrgId);
          } catch (_) {
            currentMembership = null;
          }
        }
      }

      // 4. Szerepkör meghatározása
      currentUserRole = (currentMembership?.hasPermission('admin') ?? false)
          ? MemberRole.admin
          : MemberRole.member;

      // 5. Szervezetre szűrt események és riasztások lekérése
      if (api.currentOrganizationId != null) {
        events = await api.getEvents();
        alerts = await api.getAlerts();
        try {
          coinBalance = await api.getCoinBalance();
        } catch (_) {
          coinBalance = null;
        }
      } else {
        events = [];
        alerts = [];
        coinBalance = null;
      }

      // 6. Kompatibilitási tagmodell felépítése
      if (currentUserProfile != null) {
        currentUser = Member(
          id: currentUserProfile!.user.id,
          name: currentUserProfile!.user.displayName,
          rank: currentMembership?.positions.firstOrNull ?? 'Tag',
          workplace: currentOrganization?.name ?? '',
          position: currentMembership?.positions.join(', ') ?? '',
          phone: currentUserProfile!.contactPhone ?? '',
          skills: currentMembership?.skills ?? const [],
          status: AvailabilityStatus.available,
        );
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Szervezetváltás: Kötelező a korábbi szervezet adatainak és cache-ének ürítése!
  Future<void> switchOrganization(String organizationId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // 1. Korábbi adatok ürítése a szivárgás megakadályozására
      events = [];
      alerts = [];
      coinBalance = null;
      eventResponses.clear();
      alertResponses.clear();

      // 2. Szervezetváltás az API rétegben
      await api.switchOrganization(organizationId);

      // 3. Új szervezet adatainak betöltése
      await loadData();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> respondToAlert(String alertId, bool available) async {
    try {
      final responseText = available ? 'going' : 'not_going';
      await api.setMyAlertResponse(
        alertId: alertId,
        response: responseText,
      );
      alertResponses[alertId] = available ? 'available' : 'unavailable';
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> respondToEvent(String eventId, bool going) async {
    eventResponses[eventId] = going ? 'going' : 'not_going';
    notifyListeners();
  }

  Future<void> setAvailability(AvailabilityStatus status, {DateTime? startDate, DateTime? endDate}) async {
    // Profil elérhetőség mock frissítése
    if (currentUser != null) {
      currentUser = Member(
        id: currentUser!.id,
        name: currentUser!.name,
        rank: currentUser!.rank,
        workplace: currentUser!.workplace,
        position: currentUser!.position,
        phone: currentUser!.phone,
        skills: currentUser!.skills,
        status: status,
      );
      notifyListeners();
    }
  }

  Future<void> replaceOwnSkills(List<String> skillNames) async {
    if (currentUser != null) {
      currentUser = Member(
        id: currentUser!.id,
        name: currentUser!.name,
        rank: currentUser!.rank,
        workplace: currentUser!.workplace,
        position: currentUser!.position,
        phone: currentUser!.phone,
        skills: skillNames,
        status: currentUser!.status,
      );
      notifyListeners();
    }
  }
}
