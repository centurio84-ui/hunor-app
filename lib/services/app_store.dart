import 'package:flutter/foundation.dart';
import '../api/mock_rescue_platform_api.dart';
import '../api/staging_api.dart';
import '../models/api_error.dart';
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

  int _revision = 0;
  bool get isStaging => api is StagingApi;
  String lastResponseMessage = '';
  List<Map<String,dynamic>> get pendingResponses => api is StagingApi ? (api as StagingApi).pendingResponses : [];
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
      if(api is StagingApi) await (api as StagingApi).restore();
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
      if(api is StagingApi) await (api as StagingApi).login(email,password);
      isAuthenticated = api.isAuthenticated;
      await loadData();
    } catch (e) {
      _clearLocalData();
      errorMessage = e.toString();
      isAuthenticated = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _revision++;
    _clearLocalData();
    isAuthenticated=false;
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
    currentUserRole=MemberRole.member;
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
    final revision=++_revision;
    if(!api.isAuthenticated) { _clearLocalData();isAuthenticated=false;notifyListeners();return; }
    isLoading=true;errorMessage=null;notifyListeners();
    try {
      final profile=await api.getMyProfile();
      final organizations=await api.getMyOrganizations();
      if(revision!=_revision)return;
      final orgId=api.currentOrganizationId??organizations.firstOrNull?.id;
      Membership? membership;
      List<RescueEvent> nextEvents=[];List<RescueAlert> nextAlerts=[];CoinBalance? nextCoins;
      final responses=<String,String>{};
      if(orgId!=null){
        if(api.currentOrganizationId!=orgId)await api.switchOrganization(orgId);
        membership=await api.getMyOrganizationMembership(orgId);
        nextEvents=await api.getEvents();nextAlerts=await api.getAlerts();nextCoins=await api.getCoinBalance();
        if(api is StagingApi){
          final staging=api as StagingApi;
          for(final alert in nextAlerts){
            try{
              final r=await staging.getMyResponse(alert.id);
              if(r.response=='going'||r.response=='not_going')responses[alert.id]=r.response=='going'?'available':'unavailable';
            } on ApiException catch(e){if(e.statusCode!=404)rethrow;}
          }
        }
      }
      if(revision!=_revision)return;
      currentUserProfile=profile;availableOrganizations=organizations;
      currentOrganization=organizations.where((o)=>o.id==orgId).firstOrNull;currentMembership=membership;
      currentUserRole=(membership?.hasPermission('members.manage_permissions')??false)||(membership?.hasPermission('admin')??false)?MemberRole.admin:MemberRole.member;
      events=nextEvents;alerts=nextAlerts;coinBalance=nextCoins;alertResponses=responses;
      if(api is MockRescuePlatformApi){_loadMembersForCurrentOrganization(orgId??'');}else{members=[];memberRoles.clear();alertResponseByMember.clear();}
      currentUser=Member(id:profile.user.id,name:profile.user.displayName,rank:membership?.positions.firstOrNull??'Tag',workplace:currentOrganization?.name??'',position:membership?.positions.join(', ')??'',phone:profile.contactPhone??'',skills:membership?.skills??const [],status:(membership?.alertable??false)?AvailabilityStatus.available:AvailabilityStatus.unavailable);
      isAuthenticated=true;
    } catch(e){if(revision!=_revision)return;_clearLocalData();isAuthenticated=api.isAuthenticated;errorMessage=e.toString();}
    finally{if(revision==_revision){isLoading=false;notifyListeners();}}
  }

  Future<void> syncPendingResponses() async {
    if(api is! StagingApi||!api.isAuthenticated||!pendingResponses.any((q)=>q['blocked']!=true))return;
    try{await (api as StagingApi).syncResponses();await loadData();}catch(e){if(!api.isAuthenticated){_clearLocalData();isAuthenticated=false;}errorMessage=e.toString();notifyListeners();}
  }
  Future<void> discardPendingResponse(String key) async {if(api is StagingApi){await (api as StagingApi).discardPending(key);notifyListeners();}}

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
      _revision++;
      currentOrganization=null;currentMembership=null;currentUser=null;currentUserRole=MemberRole.member;memberRoles.clear();
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
      lastResponseMessage='Válasz a szerveren rögzítve.';
      alertResponses[alertId] = available ? 'available' : 'unavailable';
      if (currentUser != null) {
        alertResponseByMember.putIfAbsent(alertId, () => {})[currentUser!.id] =
            available ? 'available' : 'unavailable';
      }
      notifyListeners();
    } on ResponsePending catch(e) {
      lastResponseMessage=e.message;errorMessage=e.message;notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> respondToEvent(String eventId, bool going) async {
    if(isStaging) throw unsupportedStaging;
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
    if(isStaging) throw unsupportedStaging;
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
    if(isStaging) throw unsupportedStaging;
    memberRoles[memberId] = role;
    notifyListeners();
  }

  Future<void> createAlert(String title, String message, String type, DateTime? expiresAt) async {
    await api.dispatchAlert(title: title, message: message, type: type, expiresAt: expiresAt);
    alerts = await api.getAlerts();
    notifyListeners();
  }

  Future<void> closeAlert(String id) async {
    if(isStaging) throw unsupportedStaging;
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
    if(isStaging) throw unsupportedStaging;
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
    if(isStaging) throw unsupportedStaging;
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
    if(isStaging) throw unsupportedStaging;
    events.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> setAvailability(AvailabilityStatus status, {DateTime? startDate, DateTime? endDate}) async {
    if(isStaging) throw unsupportedStaging;
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
    if(isStaging) throw unsupportedStaging;
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
