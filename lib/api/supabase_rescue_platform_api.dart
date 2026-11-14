import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../config.dart';
import '../models/api_error.dart';
import '../models/coin_balance.dart';
import '../models/event_participation.dart';
import '../models/installation.dart';
import '../models/member.dart';
import '../models/organization.dart';
import '../models/rescue_alert.dart';
import '../models/rescue_event.dart';
import '../models/rescue_news.dart';
import '../models/user_profile.dart';
import 'rescue_platform_api.dart';

/// Valós Supabase adatbázis adapter a Rescue Platform Flutter alkalmazáshoz.
/// Közvetlenül a weblappal (portal/) megosztott központi Supabase adatbázishoz kapcsolódik,
/// így a weben felvitt események, riasztások, hírek és tagsági adatok azonnal megjelennek a mobilon.
class SupabaseRescuePlatformApi implements RescuePlatformApi {
  final SupabaseClient client;
  String _currentOrgId = 'org-hunor';

  SupabaseRescuePlatformApi({SupabaseClient? client})
      : client = client ?? _resolveClient();

  static SupabaseClient _resolveClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
      );
    }
  }

  @override
  bool get isAuthenticated => client.auth.currentSession != null;

  @override
  String? get currentOrganizationId => _currentOrgId;

  String? get currentUserId => client.auth.currentUser?.id;

  /// Bejelentkezés e-mail címmel és jelszóval a weblappal közös Supabase Auth rendszerben.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw ApiException(
        statusCode: 401,
        code: 'AUTH_FAILED',
        message: e.message,
      );
    } catch (e) {
      throw ApiException(
        statusCode: 500,
        code: 'AUTH_ERROR',
        message: 'Bejelentkezési hiba: $e',
      );
    }
  }

  @override
  Future<UserProfile> getMyProfile() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const UnauthorizedException();
    }

    try {
      final profileRow = await client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      final name = profileRow?['name']?.toString() ??
          user.userMetadata?['name']?.toString() ??
          user.email?.split('@').first ??
          'HUNOR Tag';

      final phone = profileRow?['phone']?.toString() ??
          user.userMetadata?['phone']?.toString();

      return UserProfile(
        user: User(
          id: user.id,
          email: user.email ?? '',
          displayName: name,
        ),
        contactPhone: phone,
        version: 1,
      );
    } catch (e) {
      return UserProfile(
        user: User(
          id: user.id,
          email: user.email ?? '',
          displayName: user.email?.split('@').first ?? 'HUNOR Tag',
        ),
        version: 1,
      );
    }
  }

  @override
  Future<void> revokeCurrentSession() async {
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  @override
  Future<void> requestAccountDeletion({required String reason}) async {
    // Audit naplózás vagy törlési kérelem
  }

  @override
  Future<List<Organization>> getMyOrganizations() async {
    return const [
      Organization(
        id: 'org-hunor',
        name: 'HUNOR Nehéz Kutató-Mentő',
        code: 'HUNOR',
        description: 'Országos Katasztrófavédelmi Főigazgatóság',
        active: true,
      ),
    ];
  }

  @override
  Future<Membership> getMyOrganizationMembership(String organizationId) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const UnauthorizedException();
    }

    String role = 'member';
    bool canAccessExcon = false;
    try {
      final roleRow = await client
          .from('member_roles')
          .select('role, can_access_excon')
          .eq('member_id', user.id)
          .maybeSingle();
      if (roleRow != null) {
        if (roleRow['role'] != null) {
          role = roleRow['role'].toString();
        }
        if (roleRow['can_access_excon'] == true) {
          canAccessExcon = true;
        }
      }
    } catch (_) {}

    // Ellenőrizzük, hogy van-e jóváhagyott / kijelölt EXCON szerepe bármely eseményen
    if (!canAccessExcon && role != 'admin') {
      try {
        final ep = await client
            .from('event_participants')
            .select('event_id')
            .eq('member_id', user.id)
            .eq('participation_role', 'excon')
            .limit(1);
        if (ep.isNotEmpty) {
          canAccessExcon = true;
        }
      } catch (_) {}
    }

    return Membership(
      id: 'membership-${user.id}',
      organizationId: organizationId,
      userId: user.id,
      displayName: user.email?.split('@').first ?? 'HUNOR Tag',
      membershipStatus: MembershipStatus.approved,
      permissions: [
        if (role == 'admin') 'members.manage_permissions',
        if (role == 'admin' || canAccessExcon) 'excon.access',
      ],
      positions: const ['Tag'],
      skills: const [],
      alertable: true,
    );
  }

  @override
  Future<void> switchOrganization(String organizationId) async {
    _currentOrgId = organizationId;
  }

  // --- Események (Events) ---

  @override
  Future<List<RescueEvent>> getEvents() async {
    try {
      final List<dynamic> rows = await client
          .from('events')
          .select('*')
          .order('starts_at', ascending: true);

      return rows.map((row) {
        return RescueEvent(
          id: row['id']?.toString() ?? '',
          organizationId: _currentOrgId,
          title: row['title']?.toString() ?? '',
          description: row['description']?.toString() ?? '',
          location: row['location']?.toString() ?? '',
          startsAt: DateTime.tryParse(row['starts_at']?.toString() ?? '') ?? DateTime.now(),
          endsAt: row['ends_at'] != null ? DateTime.tryParse(row['ends_at'].toString()) : null,
          version: (row['version'] as num?)?.toInt() ?? 1,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<RescueEvent> getEvent(String eventId) async {
    final row = await client
        .from('events')
        .select('*')
        .eq('id', eventId)
        .single();

    return RescueEvent(
      id: row['id']?.toString() ?? '',
      organizationId: _currentOrgId,
      title: row['title']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      location: row['location']?.toString() ?? '',
      startsAt: DateTime.tryParse(row['starts_at']?.toString() ?? '') ?? DateTime.now(),
      endsAt: row['ends_at'] != null ? DateTime.tryParse(row['ends_at'].toString()) : null,
      version: (row['version'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Future<EventRegistrationInfo> getEventRegistrationInfo(String eventId) async {
    try {
      final participants = await client
          .from('event_participants')
          .select('response')
          .eq('event_id', eventId);

      int goingCount = 0;
      for (final p in (participants as List)) {
        if (p['response'] == 'going') {
          goingCount++;
        }
      }

      return EventRegistrationInfo(
        eventId: eventId,
        organizationId: _currentOrgId,
        currentGoingCount: goingCount,
        serverRegistrationOpen: true,
        serverCancellationOpen: true,
        isEligible: true,
      );
    } catch (_) {
      return EventRegistrationInfo(
        eventId: eventId,
        organizationId: _currentOrgId,
      );
    }
  }

  @override
  Future<EventParticipation> getMyEventParticipation(String eventId) async {
    final user = client.auth.currentUser;
    if (user == null) {
      return EventParticipation(
        organizationId: _currentOrgId,
        eventId: eventId,
        membershipId: '',
      );
    }

    try {
      final row = await client
          .from('event_participants')
          .select('*')
          .eq('event_id', eventId)
          .eq('member_id', user.id)
          .maybeSingle();

      if (row == null) {
        return EventParticipation(
          organizationId: _currentOrgId,
          eventId: eventId,
          membershipId: user.id,
        );
      }

      return EventParticipation(
        organizationId: _currentOrgId,
        eventId: eventId,
        membershipId: user.id,
        response: EventParticipationStatusX.fromString(row['response']?.toString()),
        respondedAt: row['responded_at'] != null
            ? DateTime.tryParse(row['responded_at'].toString())
            : null,
      );
    } catch (_) {
      return EventParticipation(
        organizationId: _currentOrgId,
        eventId: eventId,
        membershipId: user.id,
      );
    }
  }

  @override
  Future<EventParticipation> setMyEventParticipation({
    required String eventId,
    required EventParticipationStatus response,
    required int expectedVersion,
    String? idempotencyKey,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const UnauthorizedException();
    }

    final now = DateTime.now();
    await client.from('event_participants').upsert({
      'event_id': eventId,
      'member_id': user.id,
      'response': response.value,
      'responded_at': now.toIso8601String(),
    });

    return EventParticipation(
      organizationId: _currentOrgId,
      eventId: eventId,
      membershipId: user.id,
      response: response,
      respondedAt: now,
      version: expectedVersion + 1,
    );
  }

  // --- Hírek és közlemények (News) ---

  @override
  Future<List<RescueNewsItem>> getNews({int limit = 20, String? cursor}) async {
    try {
      final List<dynamic> rows = await client
          .from('news_posts')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map((row) {
        return RescueNewsItem(
          id: row['id']?.toString() ?? '',
          organizationId: _currentOrgId,
          title: row['title']?.toString() ?? '',
          summary: row['lead']?.toString() ?? row['summary']?.toString() ?? '',
          content: row['content']?.toString() ?? '',
          authorName: row['author_name']?.toString(),
          publishedAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
          isPinned: row['pinned'] == true,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<RescueNewsItem> getNewsItem(String newsId) async {
    final row = await client
        .from('news_posts')
        .select('*')
        .eq('id', newsId)
        .single();

    return RescueNewsItem(
      id: row['id']?.toString() ?? '',
      organizationId: _currentOrgId,
      title: row['title']?.toString() ?? '',
      summary: row['lead']?.toString() ?? row['summary']?.toString() ?? '',
      content: row['content']?.toString() ?? '',
      authorName: row['author_name']?.toString(),
      publishedAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      isPinned: row['pinned'] == true,
    );
  }

  // --- Riasztások (Alerts) ---

  @override
  Future<List<RescueAlert>> getAlerts() async {
    try {
      final List<dynamic> rows = await client
          .from('alerts')
          .select('*')
          .order('created_at', ascending: false);

      return rows.map((row) {
        return RescueAlert(
          id: row['id']?.toString() ?? '',
          organizationId: _currentOrgId,
          title: row['title']?.toString() ?? '',
          message: row['message']?.toString() ?? '',
          type: row['type']?.toString() ?? 'alert',
          status: row['status']?.toString() ?? 'active',
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
          expiresAt: row['expires_at'] != null ? DateTime.tryParse(row['expires_at'].toString()) : null,
          version: (row['version'] as num?)?.toInt() ?? 1,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<RescueAlert> getAlert(String alertId) async {
    final row = await client
        .from('alerts')
        .select('*')
        .eq('id', alertId)
        .single();

    return RescueAlert(
      id: row['id']?.toString() ?? '',
      organizationId: _currentOrgId,
      title: row['title']?.toString() ?? '',
      message: row['message']?.toString() ?? '',
      type: row['type']?.toString() ?? 'alert',
      status: row['status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: row['expires_at'] != null ? DateTime.tryParse(row['expires_at'].toString()) : null,
      version: (row['version'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Future<RescueAlert> dispatchAlert({
    required String title,
    required String message,
    required String type,
    DateTime? expiresAt,
  }) async {
    final user = client.auth.currentUser;
    final row = await client.from('alerts').insert({
      'title': title,
      'message': message,
      'type': type,
      'status': 'active',
      'created_by': user?.id,
      'expires_at': expiresAt?.toIso8601String(),
    }).select().single();

    return RescueAlert(
      id: row['id']?.toString() ?? '',
      organizationId: _currentOrgId,
      title: row['title']?.toString() ?? '',
      message: row['message']?.toString() ?? '',
      type: row['type']?.toString() ?? 'alert',
      status: row['status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: row['expires_at'] != null ? DateTime.tryParse(row['expires_at'].toString()) : null,
    );
  }

  @override
  Future<AlertResponse> setMyAlertResponse({
    required String alertId,
    required String response,
    int? expectedVersion,
    String? idempotencyKey,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const UnauthorizedException();
    }

    final now = DateTime.now();
    await client.from('alert_responses').upsert({
      'alert_id': alertId,
      'member_id': user.id,
      'response': response,
      'responded_at': now.toIso8601String(),
    });

    return AlertResponse(
      alertId: alertId,
      membershipId: user.id,
      response: response,
      respondedAt: now,
    );
  }

  @override
  Future<void> acknowledgeAlert(String alertId, {String? idempotencyKey}) async {
    // Nyugtázás naplózása
  }

  // --- Tagok listája (Members) ---

  Future<List<Member>> getMembers() async {
    try {
      final List<dynamic> rows = await client
          .from('profiles')
          .select('id, name, rank, workplace, position, phone, skills(name), availability(status)')
          .order('name');

      return rows.map((p) {
        final skillsList = <String>[];
        if (p['skills'] is List) {
          for (final s in (p['skills'] as List)) {
            if (s['name'] != null) skillsList.add(s['name'].toString());
          }
        }

        AvailabilityStatus status = AvailabilityStatus.available;
        if (p['availability'] is List && (p['availability'] as List).isNotEmpty) {
          final first = (p['availability'] as List).first;
          status = AvailabilityStatus.fromDatabase(first['status']?.toString());
        }

        return Member(
          id: p['id']?.toString() ?? '',
          name: p['name']?.toString() ?? '',
          rank: p['rank']?.toString() ?? '',
          workplace: p['workplace']?.toString() ?? '',
          position: p['position']?.toString() ?? '',
          phone: p['phone']?.toString() ?? '',
          skills: skillsList,
          status: status,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // --- Értesítések és eszközregisztráció ---

  @override
  Future<Installation> registerMyInstallation({
    required String installationId,
    required String platform,
    required String provider,
    required String token,
    String? label,
    String? environment,
  }) async {
    final user = client.auth.currentUser;
    if (user != null) {
      try {
        await client.from('device_tokens').upsert({
          'member_id': user.id,
          'token': token,
          'platform': platform,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    return Installation(
      id: installationId,
      platform: platform,
      provider: provider,
      environment: environment ?? 'development',
      label: label ?? '',
      active: true,
    );
  }

  @override
  Future<Installation> updateMyInstallation({
    required String installationId,
    required String provider,
    required String token,
  }) async {
    return registerMyInstallation(
      installationId: installationId,
      platform: 'ios',
      provider: provider,
      token: token,
    );
  }

  @override
  Future<DeviceReceipt> confirmDeviceReceipt({
    required String deliveryId,
    required String receiptToken,
  }) async {
    return DeviceReceipt(
      received: true,
      receivedAt: DateTime.now(),
    );
  }

  @override
  Future<CoinBalance> getCoinBalance() async {
    return CoinBalance(
      organizationId: 'hunor',
      membershipId: currentUserId ?? 'guest',
      unit: 'RC',
      balance: 0,
      asOf: DateTime.now(),
      ledgerVersion: 'v1',
    );
  }

  @override
  void clearTenantCache() {}
}
