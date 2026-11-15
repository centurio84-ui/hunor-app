import 'dart:async';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../api/mock_rescue_platform_api.dart';
import '../api/staging_api.dart';
import '../api/supabase_rescue_platform_api.dart';
import '../models/api_error.dart';
import '../api/rescue_platform_api.dart';
import '../models/coin_balance.dart';
import '../models/event_participation.dart';
import '../models/member.dart';
import '../models/organization.dart';
import '../models/organization_capabilities.dart';
import '../models/rescue_alert.dart';
import '../models/rescue_event.dart';
import '../models/rescue_news.dart';
import '../models/user_profile.dart';
import 'theme_controller.dart';

enum MemberRole { member, admin }

/// AppStore – Központi állapotkezelő a Rescue Platform Flutter mobilalkalmazáshoz.
/// Támogatja a RescuePlatformApi és MockRescuePlatformApi használatát,
/// megvalósítja a többszervezetes adatizolációt, a taglisták kezelését és a szervezetváltási cache-ürítést.
class AppStore extends ChangeNotifier {
  final RescuePlatformApi api;
  final ThemeController? themeController;

  AppStore({RescuePlatformApi? api, this.themeController}) : api = api ?? MockRescuePlatformApi();

  int _revision = 0;
  bool get isStaging => api is StagingApi;
  bool get isSupabase => api is SupabaseRescuePlatformApi;
  String lastResponseMessage = '';
  List<Map<String,dynamic>> get pendingResponses => api is StagingApi ? (api as StagingApi).pendingResponses : [];
  UserProfile? currentUserProfile;
  Member? currentUser;
  Organization? currentOrganization;
  Membership? currentMembership;
  List<Organization> availableOrganizations = [];
  List<RescueEvent> events = [];
  List<RescueAlert> alerts = [];
  List<RescueNewsItem> news = [];
  Map<String, EventParticipation> eventParticipations = {};
  Map<String, EventRegistrationInfo> eventRegistrations = {};
  List<Member> members = [];
  List<ChatMessage> chatMessages = [];
  int unreadChatCount = 0;
  int unreadNewsCount = 0;
  int unreadEventsCount = 0;
  int get totalNotificationCount => unreadChatCount + unreadNewsCount + unreadEventsCount;
  bool _isChatSubscribed = false;

  Future<void> _syncAppBadge() async {
    try {
      final count = totalNotificationCount;
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(count);
      }
    } catch (_) {}
  }

  void triggerNotificationChime() {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  Future<void> simulateTestNotification() async {
    unreadChatCount++;
    triggerNotificationChime();
    await _syncAppBadge();
    notifyListeners();
  }

  void markChatAsRead() {
    if (unreadChatCount > 0) {
      unreadChatCount = 0;
      unawaited(_syncAppBadge());
      notifyListeners();
    }
  }

  void markNewsAsRead() {
    if (unreadNewsCount > 0) {
      unreadNewsCount = 0;
      unawaited(_syncAppBadge());
      notifyListeners();
    }
  }

  void markEventsAsRead() {
    if (unreadEventsCount > 0) {
      unreadEventsCount = 0;
      unawaited(_syncAppBadge());
      notifyListeners();
    }
  }

  Future<void> loadChatMessages() async {
    if (api is SupabaseRescuePlatformApi) {
      chatMessages = await (api as SupabaseRescuePlatformApi).getChatMessages();
      notifyListeners();
    }
  }

  Future<void> sendChatMessage(String content) async {
    if (api is SupabaseRescuePlatformApi) {
      await (api as SupabaseRescuePlatformApi).sendChatMessage(content);
      await loadChatMessages();
    }
  }
  CoinBalance? coinBalance;
  OrganizationCapabilities? capabilities;
  // Rescue Coins is frozen. Legacy read API/data are preserved, not loaded by the UI.
  bool get showRescueCoins => false;

  Map<String, String> eventResponses = {};
  Map<String, String> alertResponses = {};
  Map<String, Map<String, String>> alertResponseByMember = {};
  Map<String, MemberRole> memberRoles = {};
  MemberRole currentUserRole = MemberRole.member;
  bool get isAdmin => currentUserRole == MemberRole.admin;
  bool get canAccessExcon => !isGuest && (isAdmin || (currentMembership?.permissions.contains('excon.access') ?? false));

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

  bool isGuest = false;

  Future<void> enterAsGuest() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      isGuest = true;
      isAuthenticated = true;
      currentUserProfile = UserProfile(
        user: const User(id: 'guest', email: 'vendeg@hun01usar.hu', displayName: 'HUNOR Vendég'),
        version: 1,
      );
      currentUser = const Member(
        id: 'guest',
        name: 'HUNOR Vendég',
        rank: 'Érdeklődő',
        workplace: 'Központi Portál',
        position: 'Vendég / Érdeklődő',
        phone: '-',
        skills: [],
        status: AvailabilityStatus.available,
      );
      currentOrganization = const Organization(
        id: 'org-hunor',
        name: 'HUNOR Nehéz Kutató-Mentő',
        code: 'HUNOR',
        description: 'Országos Katasztrófavédelmi Főigazgatóság',
        active: true,
      );
      currentMembership = const Membership(
        id: 'membership-guest',
        organizationId: 'org-hunor',
        userId: 'guest',
        displayName: 'HUNOR Vendég',
        membershipStatus: MembershipStatus.approved,
        permissions: [],
        positions: ['Vendég'],
        skills: [],
        alertable: false,
      );

      if (api is SupabaseRescuePlatformApi) {
        try { events = await api.getEvents(); } catch (_) {}
        try { news = await api.getNews(); } catch (_) {}
        try { alerts = await api.getAlerts(); } catch (_) {}
      } else {
        await loadData();
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
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
      if (api is StagingApi) await (api as StagingApi).login(email, password);
      if (api is SupabaseRescuePlatformApi) {
        await (api as SupabaseRescuePlatformApi).signInWithPassword(
          email: email,
          password: password,
        );
      }
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
    isAuthenticated = false;
    isGuest = false;
    isLoading = true;
    notifyListeners();

    try {
      await api.revokeCurrentSession();
      // Kijelentkezéskor kötelező az összes szervezeti adat ürítése
      _clearLocalData();
      isAuthenticated = false;
      await themeController?.onUserSignedOut();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Hitelesített fióktörlési kérelem indítása
  Future<void> requestAccountDeletion({String reason = 'Felhasználói fióktörlési kérelem a mobilalkalmazásból'}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await api.requestAccountDeletion(reason: reason);
      _revision++;
      _clearLocalData();
      isAuthenticated = false;
      await themeController?.onUserSignedOut();
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
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
    news = [];
    eventParticipations.clear();
    eventRegistrations.clear();
    members = [];
    coinBalance = null;
    capabilities = null;
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
      List<RescueEvent> nextEvents=[];List<RescueAlert> nextAlerts=[];
      List<RescueNewsItem> nextNews=[];
      final nextParticipations=<String, EventParticipation>{};
      final nextRegistrations=<String, EventRegistrationInfo>{};
      OrganizationCapabilities? nextCapabilities;
      final responses=<String,String>{};
      if(orgId!=null){
        if(api.currentOrganizationId!=orgId)await api.switchOrganization(orgId);
        membership=await api.getMyOrganizationMembership(orgId);
        nextEvents=await api.getEvents();nextAlerts=await api.getAlerts();
        try { nextNews=await api.getNews(); } catch (_) { nextNews=[]; }

        // Betöltjük az eseményekhez a regisztrációt és saját részvételt
        for(final ev in nextEvents) {
          try {
            final reg = await api.getEventRegistrationInfo(ev.id);
            nextRegistrations[ev.id] = reg;
            final part = await api.getMyEventParticipation(ev.id);
            nextParticipations[ev.id] = part;
            if(part.response != null) {
              eventResponses[ev.id] = part.response!.value;
            }
          } catch (_) {}
        }
        if(api is StagingApi){
          final staging=api as StagingApi;
          nextCapabilities=await staging.getMyCapabilities(membership);
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
      capabilities=nextCapabilities;
      currentUserRole=isStaging
          ? ((capabilities?.allows('members.manage_permissions')??false)?MemberRole.admin:MemberRole.member)
          : ((membership?.hasPermission('members.manage_permissions')??false)?MemberRole.admin:MemberRole.member);
      events=nextEvents;alerts=nextAlerts;news=nextNews;eventParticipations=nextParticipations;eventRegistrations=nextRegistrations;coinBalance=null;alertResponses=responses;
      if (api is SupabaseRescuePlatformApi) {
        members = await (api as SupabaseRescuePlatformApi).getMembers();
        unawaited((api as SupabaseRescuePlatformApi).recordAppHeartbeat());
        chatMessages = await (api as SupabaseRescuePlatformApi).getChatMessages();
        if (!_isChatSubscribed) {
          _isChatSubscribed = true;
          (api as SupabaseRescuePlatformApi).subscribeToChat((msg) {
            final myId = currentUser?.id ?? profile.user.id;
            if (msg.authorId != myId) {
              unreadChatCount++;
              triggerNotificationChime();
              unawaited(_syncAppBadge());
            }
            if (!chatMessages.any((m) => m.id == msg.id)) {
              chatMessages.add(msg);
            }
            notifyListeners();
          });
        }
      } else if (api is MockRescuePlatformApi) {
        _loadMembersForCurrentOrganization(orgId ?? '');
      } else {
        members = [];
        memberRoles.clear();
        alertResponseByMember.clear();
      }
      final myMember = members.where((m) => m.id == profile.user.id).firstOrNull;
      final effectiveSkills = myMember?.skills ?? membership?.skills ?? const <String>[];
      currentUser = Member(
        id: profile.user.id,
        name: profile.user.displayName,
        rank: myMember?.rank ?? membership?.positions.firstOrNull ?? 'Tag',
        workplace: myMember?.workplace ?? currentOrganization?.name ?? '',
        position: myMember?.position ?? membership?.positions.join(', ') ?? '',
        phone: profile.contactPhone ?? myMember?.phone ?? '',
        skills: effectiveSkills,
        status: myMember?.status ?? ((membership?.alertable ?? false) ? AvailabilityStatus.available : AvailabilityStatus.unavailable),
      );
      isAuthenticated=true;
      if (themeController != null && orgId != null) {
        await themeController!.onUserSignedIn(
          userId: profile.user.id,
          organizationId: orgId,
        );
      }
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
      capabilities=null;
      // 1. Korábbi adatok ürítése a szivárgás megakadályozására
      events = [];
      alerts = [];
      news = [];
      eventParticipations.clear();
      eventRegistrations.clear();
      members = [];
      coinBalance = null;
      eventResponses.clear();
      alertResponses.clear();
      alertResponseByMember.clear();

      // 2. Szervezetváltás az API rétegben
      await api.switchOrganization(organizationId);
      await themeController?.onOrganizationChanged(organizationId);

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
    try {
      final currentPart = eventParticipations[eventId];
      final currentVersion = currentPart?.version ?? 0;
      final targetStatus = going ? EventParticipationStatus.going : EventParticipationStatus.notGoing;

      final updated = await api.setMyEventParticipation(
        eventId: eventId,
        response: targetStatus,
        expectedVersion: currentVersion,
      );

      eventParticipations[eventId] = updated;
      eventResponses[eventId] = updated.response?.value ?? (going ? 'going' : 'not_going');
      lastResponseMessage = 'Részvételi szándék (${going ? "Részt veszek" : "Nem veszek részt"}) rögzítve.';

      // Részvételi válasz után frissítjük az esemény kapacitás/szabály információit a legfrissebb szerverállapotra
      try {
        final freshReg = await api.getEventRegistrationInfo(eventId);
        eventRegistrations[eventId] = freshReg;
      } catch (_) {}

      notifyListeners();
    } on PreconditionFailedException catch (_) {
      // 412 VERSION_CONFLICT: frissítjük az állapotot
      errorMessage = 'A részvételi állapot időközben módosult a szerveren. Kérjük próbáld újra!';
      try {
        final freshPart = await api.getMyEventParticipation(eventId);
        eventParticipations[eventId] = freshPart;
        if (freshPart.response != null) eventResponses[eventId] = freshPart.response!.value;
      } catch (_) {}
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
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
    if (isStaging) throw unsupportedStaging;
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

      final memberIdx = members.indexWhere((m) => m.id == currentUser!.id);
      if (memberIdx != -1) {
        final old = members[memberIdx];
        members[memberIdx] = Member(
          id: old.id,
          name: old.name,
          rank: old.rank,
          workplace: old.workplace,
          position: old.position,
          phone: old.phone,
          skills: skillNames,
          status: old.status,
        );
      }

      if (api is SupabaseRescuePlatformApi && !isGuest) {
        try {
          final client = (api as SupabaseRescuePlatformApi).client;
          final uid = client.auth.currentUser?.id;
          if (uid != null) {
            await client.from('skills').delete().eq('member_id', uid);
            if (skillNames.isNotEmpty) {
              await client.from('skills').insert([
                for (final name in skillNames)
                  {'member_id': uid, 'name': name}
              ]);
            }
          }
        } catch (e) {
          debugPrint('Hiba a képességek Supabase-mentésekor: $e');
        }
      }
      notifyListeners();
    }
  }
}
