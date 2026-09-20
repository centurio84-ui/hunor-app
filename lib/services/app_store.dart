import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/member.dart';

final supabase = Supabase.instance.client;

class HunorEvent {
  final String id, title, location, details;
  final DateTime date;
  const HunorEvent({required this.id, required this.title, required this.location, required this.details, required this.date});
}

class HunorAlert {
  final String id, title, message, type, status;
  final DateTime createdAt;
  const HunorAlert({required this.id, required this.title, required this.message, required this.type, required this.status, required this.createdAt});
  String get typeLabel => switch (type) {
    'exercise' => 'GYAKORLAT',
    'standby' => 'KÉSZENLÉTBE HELYEZÉS',
    _ => 'RIASZTÁS',
  };
}

enum MemberRole { member, admin }

class AppStore extends ChangeNotifier {
  Member? currentUser;
  List<Member> members = [];
  List<HunorEvent> events = [];
  List<HunorAlert> alerts = [];
  Map<String, String> eventResponses = {};
  Map<String, String> alertResponses = {};
  MemberRole currentUserRole = MemberRole.member;
  bool isAuthenticated = false, isLoading = false, initialized = false;
  String? errorMessage;

  Future<void> initialize() async {
    isAuthenticated = supabase.auth.currentSession != null;
    if (isAuthenticated) await loadData();
    initialized = true;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    isLoading = true; errorMessage = null; notifyListeners();
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      isAuthenticated = true;
      await loadData();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    isAuthenticated = false; currentUser = null;
    members = []; events = []; alerts = [];
    notifyListeners();
  }

  Future<void> loadData() async {
    final session = supabase.auth.currentSession;
    if (session == null) { isAuthenticated = false; notifyListeners(); return; }
    isLoading = true; errorMessage = null; notifyListeners();
    try {
      final uid = session.user.id;
      final profiles = await supabase.from('profiles').select();
      final skills = await supabase.from('skills').select();
      final availability = await supabase.from('availability').select();
      final dbEvents = await supabase.from('events').select().order('starts_at', ascending: true);
      final roles = await supabase.from('member_roles').select();
      final ownEvents = await supabase.from('event_participants').select().eq('member_id', uid);
      final dbAlerts = await supabase.from('alerts').select().order('created_at', ascending: false);
      final ownAlerts = await supabase.from('alert_responses').select().eq('member_id', uid);

      currentUserRole = roles.any((r) => r['member_id'] == uid && r['role'] == 'admin')
          ? MemberRole.admin : MemberRole.member;

      DateTime? date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

      members = profiles.map<Member>((p) {
        final id = p['id'].toString();
        final active = availability.where((a) {
          final start = date(a['start_date']); final end = date(a['end_date']);
          final now = DateTime.now();
          return a['member_id'].toString() == id && start != null &&
              !start.isAfter(now) && (end == null || !end.isBefore(now));
        }).toList()..sort((a,b) => b['start_date'].toString().compareTo(a['start_date'].toString()));
        return Member(
          id: id, name: p['name']?.toString() ?? '', rank: p['rank']?.toString() ?? '',
          workplace: p['workplace']?.toString() ?? '', position: p['position']?.toString() ?? '',
          phone: p['phone']?.toString() ?? '',
          skills: skills.where((s) => s['member_id'].toString() == id).map((s) => s['name'].toString()).toList(),
          status: AvailabilityStatus.fromDatabase(active.isEmpty ? null : active.first['status']?.toString()),
        );
      }).toList();

      currentUser = members.where((m) => m.id == uid).firstOrNull;
      events = dbEvents.map<HunorEvent>((e) => HunorEvent(
        id: e['id'].toString(), title: e['title'].toString(),
        date: date(e['starts_at']) ?? DateTime.now(), location: e['location']?.toString() ?? '',
        details: e['description']?.toString() ?? '',
      )).toList();
      alerts = dbAlerts.map<HunorAlert>((a) => HunorAlert(
        id: a['id'].toString(), title: a['title'].toString(), message: a['message'].toString(),
        type: a['type'].toString(), status: a['status'].toString(),
        createdAt: date(a['created_at']) ?? DateTime.now(),
      )).toList();
      eventResponses = {for (final r in ownEvents) r['event_id'].toString(): r['response'].toString()};
      alertResponses = {for (final r in ownAlerts) r['alert_id'].toString(): r['response'].toString()};
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  Future<void> updateMember(Member member, {required String name, required String rank, required String workplace, required String position, required String phone}) async {
    await supabase.from('profiles').update({
      'name': name, 'rank': rank, 'workplace': workplace, 'position': position, 'phone': phone,
    }).eq('id', member.id);
    await loadData();
  }

  Future<void> updateMemberRole(String memberId, MemberRole role) async {
    await supabase.from('member_roles').upsert({
      'member_id': memberId, 'role': role == MemberRole.admin ? 'admin' : 'member',
    }, onConflict: 'member_id');
    await loadData();
  }

  Future<void> createEvent(String title, DateTime date, String location, String details) async {
    await supabase.from('events').insert({
      'title': title, 'starts_at': date.toIso8601String(),
      'location': location, 'description': details,
    });
    await loadData();
  }

  Future<void> updateEvent(String id, String title, DateTime date, String location, String details) async {
    await supabase.from('events').update({
      'title': title, 'starts_at': date.toIso8601String(),
      'location': location, 'description': details,
    }).eq('id', id);
    await loadData();
  }

  Future<void> deleteEvent(String id) async {
    await supabase.from('events').delete().eq('id', id);
    await loadData();
  }

  Future<void> createAlert(String title, String message, String type, DateTime? expiresAt) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await supabase.from('alerts').insert({
      'title': title, 'message': message, 'type': type,
      'status': 'active', 'created_by': uid,
      'expires_at': expiresAt?.toIso8601String(),
    });
    await loadData();
  }

  Future<void> respondToEvent(String id, bool going) async {
    final uid = currentUser?.id; if (uid == null) return;
    final response = going ? 'going' : 'not_going';
    await supabase.from('event_participants').upsert({
      'event_id': id, 'member_id': uid, 'response': response,
      'responded_at': DateTime.now().toIso8601String(),
    }, onConflict: 'event_id,member_id');
    await loadData();
  }

  Future<void> respondToAlert(String id, bool available) async {
    final uid = currentUser?.id; if (uid == null) return;
    await supabase.from('alert_responses').upsert({
      'alert_id': id, 'member_id': uid,
      'response': available ? 'available' : 'unavailable',
    }, onConflict: 'alert_id,member_id');
    await loadData();
  }
}
