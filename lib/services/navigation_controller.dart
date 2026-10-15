import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/navigation_tab.dart';

/// HUNOR-only adapter. Not a multitenant API; no service-role key is used.
class NavigationController extends ChangeNotifier {
  NavigationController(this.client) {
    _auth = client.auth.onAuthStateChange.listen((_) => _syncIdentity());
    unawaited(_syncIdentity());
  }
  final SupabaseClient client;
  List<NavigationTab> tabs = const [];
  bool ready = false, isAdmin = false, isApproved = false;
  String? error;
  final Set<String> saving = {};
  StreamSubscription<AuthState>? _auth;
  StreamSubscription<List<Map<String, dynamic>>>? _rows;
  RealtimeChannel? _identityChannel;
  String? _actor;
  int _generation = 0;
  bool _disposed = false;
  static const adminRoutes = {'/admin', '/navigation-settings', '/approvals', '/quizadmin'};
  bool canOpen(String path) {
    if (!ready || !isApproved) return false;
    if (path == '/navigation-settings') return isAdmin;
    if (adminRoutes.contains(path) && !isAdmin) return false;
    final found = tabs.where((t) => t.routePath == path);
    return found.isNotEmpty && (isAdmin || found.first.isVisible);
  }
  Future<void> _syncIdentity() async {
    final actor = client.auth.currentUser?.id;
    final generation = ++_generation;
    ready = false; isAdmin = false; isApproved = false; tabs = const []; error = null;
    _actor = actor; saving.clear();
    final rows = _rows; _rows = null;
    final channel = _identityChannel; _identityChannel = null;
    if (!_disposed) notifyListeners();
    await rows?.cancel();
    if (channel != null) await client.removeChannel(channel);
    if (_disposed || generation != _generation || actor == null) return;
    try {
      final context = await client.rpc('navigation_access_context');
      if (!_current(generation, actor)) return;
      isAdmin = context['is_admin'] == true;
      isApproved = context['is_approved_member'] == true;
      // Subscribe to ALL rows: true -> false must also arrive.
      _rows = client.from('navigation_tabs').stream(primaryKey: ['id'])
        .order('sort_order').listen((rows) {
          if (!_current(generation, actor)) return;
          tabs = rows.map(NavigationTab.fromJson).toList()
            ..sort((a,b) {final order=a.sortOrder.compareTo(b.sortOrder);return order != 0 ? order : a.id.compareTo(b.id);});
          ready = true; error = null; notifyListeners();
        }, onError: (Object e) {
          if (!_current(generation, actor)) return;
          ready = false; tabs = const []; error = 'A menübeállítások nem tölthetők be.'; notifyListeners();
        });
      _identityChannel = client.channel('hunor-navigation-role-$actor')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'member_roles',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'member_id', value: actor),
          callback: (_) { unawaited(_syncIdentity()); })
        .onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'profiles',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: actor),
          callback: (_) { unawaited(_syncIdentity()); })
        .subscribe();
    } catch (_) {
      if (!_current(generation, actor)) return;
      ready = false; error = 'A menübeállítások nem ellenőrizhetők.'; notifyListeners();
    }
  }
  bool _current(int generation, String actor) => !_disposed && generation == _generation &&
    _actor == actor && client.auth.currentUser?.id == actor;
  Future<void> refresh() => _syncIdentity();
  Future<void> setVisible(NavigationTab tab, bool value) async {
    if (!ready || !isAdmin || !isApproved) throw StateError('Adminisztrátori jogosultság szükséges.');
    if (!saving.add(tab.id)) return;
    final actor = _actor; final generation = _generation; notifyListeners();
    try {
      await client.from('navigation_tabs').update({'is_visible': value}).eq('id', tab.id).select('id').single();
    } finally {
      if (!_disposed && generation == _generation && actor == _actor) {saving.remove(tab.id); notifyListeners();}
    }
  }
  @override
  void dispose() {
    _disposed = true; _generation++;
    unawaited(_auth?.cancel()); unawaited(_rows?.cancel());
    final channel = _identityChannel;
    if (channel != null) unawaited(client.removeChannel(channel));
    super.dispose();
  }
}
