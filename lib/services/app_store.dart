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
/// megvalósítja a többszervezetes adatizolációt, a taglisták kezelését és a szervezetváltási cache-ürítést.
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
  List<Member> members = [];
  CoinBalance? coinBalance;

  Map<String, String> eventResponses = {};
  Map<String, String> alertResponses = {};
  Map<String, Map<String, String>> alertResponseByMember = {};
  Map<String, MemberRole> memberRoles = {};
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
    members = [];
    coinBalance = null;
    eventResponses.clear();
    alertResponses.clear();
    alertResponseByMember.clear();
    memberRoles.clear();
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

      // 5. Szervezetre szűrt események, riasztások és egyenleg
      if (api.currentOrganizationId != null) {
        events = await api.getEvents();
        alerts = await api.getAlerts();
        try {
          coinBalance = await api.getCoinBalance();
        } catch (_) {
          coinBalance = null;
        }

        // 6. Szervezeti állomány (members) betöltése a multi-tenant izoláció szerint
        _loadMembersForCurrentOrganization(activeOrgId ?? '');
      } else {
        events = [];
        alerts = [];
        members = [];
        coinBalance = null;
      }

      // 7. Kompatibilitási tagmodell felépítése az aktuális felhasználóhoz
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

  void _loadMembersForCurrentOrganization(String orgId) {
    if (orgId == MockRescuePlatformApi.orgAId) {
      // HUNOR tagok
      members = [
        Member(
          id: MockRescuePlatformApi.mockUserId,
          name: currentUserProfile?.user.displayName ?? 'Mock Tag',
          rank: 'Tű. őrnagy',
          workplace: 'HUNOR Nehéz Kutató-Mentő',
          position: 'Műveletirányító',
          phone: '+36-20-000-0001',
          skills: const ['USAR', 'rope_access', 'command'],
          status: AvailabilityStatus.available,
        ),
        const Member(
          id: 'member-hunor-02',
          name: 'Kovács Péter',
          rank: 'Tű. százados',
          workplace: 'HUNOR Műveleti Csoport',
          position: 'Mentőtiszt',
          phone: '+36-20-000-0002',
          skills: ['Shoring', 'Breaching', 'Medic'],
          status: AvailabilityStatus.available,
        ),
        const Member(
          id: 'member-hunor-03',
          name: 'Nagy Ádám',
          rank: 'Tű. főtörzsőrmester',
          workplace: 'HUNOR Kutyás Egység',
          position: 'Keresőkutya-vezető',
          phone: '+36-20-000-0003',
          skills: ['K9 Search', 'Canine First Aid'],
          status: AvailabilityStatus.training,
        ),
      ];
    } else {
      // BMSZ tagok
      members = [
        Member(
          id: MockRescuePlatformApi.mockUserId,
          name: currentUserProfile?.user.displayName ?? 'Mock Tag',
          rank: 'Mentésvezető',
          workplace: 'Barlangi Mentőszolgálat',
          position: 'Kötéltechnikai mentő',
          phone: '+36-30-000-0001',
          skills: const ['cave_rescue', 'vertical_rigging'],
          status: AvailabilityStatus.available,
        ),
        const Member(
          id: 'member-bmsz-02',
          name: 'Szabó Zoltán',
          rank: 'Barlangi mentőorvos',
          workplace: 'BMSZ Egészségügyi Csoport',
          position: 'Orvos',
          phone: '+36-30-000-0002',
          skills: ['Cave Medicine', 'Hypothermia Protocol'],
          status: AvailabilityStatus.available,
        ),
      ];
    }

    memberRoles = {
      MockRescuePlatformApi.mockUserId: MemberRole.admin,
      for (final m in members)
        if (m.id != MockRescuePlatformApi.mockUserId) m.id: MemberRole.member,
    };

    // Riasztási válaszok mock inicializálása
    alertResponseByMember = {
      for (final a in alerts)
        a.id: {
          MockRescuePlatformApi.mockUserId: alertResponses[a.id] ?? 'available',
          if (members.length > 1) members[1].id: 'available',
        },
    };
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
      members = [];
      coinBalance = null;
      eventResponses.clear();
      alertResponses.clear();
      alertResponseByMember.clear();

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
      if (currentUser != null) {
        alertResponseByMember.putIfAbsent(alertId, () => {})[currentUser!.id] =
            available ? 'available' : 'unavailable';
      }
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

  MemberRole roleForMember(String memberId) => memberRoles[memberId] ?? MemberRole.member;

  Future<void> updateMember(
    Member member, {
    required String name,
    required String rank,
    required String workplace,
    required String position,
    required String phone,
  }) async {
    final idx = members.indexWhere((m) => m.id == member.id);
    if (idx >= 0) {
      members[idx] = Member(
        id: member.id,
        name: name,
        rank: rank,
        workplace: workplace,
        position: position,
        phone: phone,
        skills: member.skills,
        status: member.status,
      );
      notifyListeners();
    }
  }

  Future<void> updateMemberRole(String memberId, MemberRole role) async {
    memberRoles[memberId] = role;
    notifyListeners();
  }

  Future<void> createAlert(String title, String message, String type, DateTime? expiresAt) async {
    await api.dispatchAlert(title: title, message: message, type: type, expiresAt: expiresAt);
    alerts = await api.getAlerts();
    notifyListeners();
  }

  Future<void> closeAlert(String id) async {
    final idx = alerts.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      final old = alerts[idx];
      alerts[idx] = RescueAlert(
        id: old.id,
        organizationId: old.organizationId,
        title: old.title,
        message: old.message,
        type: old.type,
        status: 'closed',
        createdAt: old.createdAt,
        expiresAt: old.expiresAt,
        version: old.version + 1,
      );
      notifyListeners();
    }
  }

  Future<void> createEvent(String title, DateTime date, String location, String details) async {
    final newEvent = RescueEvent(
      id: 'event-${DateTime.now().millisecondsSinceEpoch}',
      organizationId: currentOrganization?.id ?? '',
      title: title,
      description: details,
      location: location,
      startsAt: date,
      version: 1,
    );
    events.add(newEvent);
    notifyListeners();
  }

  Future<void> updateEvent(String id, String title, DateTime date, String location, String details) async {
    final idx = events.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      events[idx] = RescueEvent(
        id: id,
        organizationId: events[idx].organizationId,
        title: title,
        description: details,
        location: location,
        startsAt: date,
        version: events[idx].version + 1,
      );
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String id) async {
    events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> setAvailability(AvailabilityStatus status, {DateTime? startDate, DateTime? endDate}) async {
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
