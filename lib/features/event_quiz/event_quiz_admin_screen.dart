import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_store.dart';
import '../../services/local_notification_service.dart';
import '../../theme/hunor_theme.dart';
import 'device_hash_helper.dart';
import 'event_quiz_models.dart';
import 'event_quiz_repository.dart';

enum _EventStatusFilter { all, active, inactive }

class EventQuizAdminScreen extends StatefulWidget {
  const EventQuizAdminScreen({
    super.key,
    this.onReturnToPortal,
    this.embedded = false,
  });

  final VoidCallback? onReturnToPortal;
  final bool embedded;

  @override
  State<EventQuizAdminScreen> createState() => _EventQuizAdminScreenState();
}

class _EventQuizAdminScreenState extends State<EventQuizAdminScreen> {
  late final EventQuizRepository _repo =
      EventQuizRepository(Supabase.instance.client);

  bool _loading = true;
  String? _error;
  List<QuizEvent> _events = [];
  List<QuizCategoryStat> _categoryStats = [];
  List<QuizHourlyNotification> _hourlyNotifications = [];
  final Set<String> _seenNotificationIds = <String>{};
  bool _initialNotifsSeeded = false;
  _EventStatusFilter _statusFilter = _EventStatusFilter.all;
  Timer? _pollTimer;
  Timer? _hourlyCheckTimer;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _subscribeRealtime();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _loadAll(silent: true),
    );
    _hourlyCheckTimer = Timer.periodic(
      const Duration(seconds: 55),
      (_) => _checkHourlyLeaderDigest(forceNow: false),
    );
  }

  void _subscribeRealtime() {
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('quiz_event_submissions_live')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'quiz_event_submissions',
            callback: (_) => _loadAll(silent: true),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'quiz_event_hourly_notifications',
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec.isNotEmpty) {
                _handleIncomingHourlyNotification(
                  QuizHourlyNotification.fromJson(
                    Map<String, dynamic>.from(rec),
                  ),
                );
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _handleIncomingHourlyNotification(
    QuizHourlyNotification notif,
  ) async {
    if (notif.id.isEmpty || _seenNotificationIds.contains(notif.id)) return;
    _seenNotificationIds.add(notif.id);

    if (mounted) {
      setState(() {
        _hourlyNotifications = [
          notif,
          ..._hourlyNotifications.where((n) => n.id != notif.id),
        ].take(20).toList();
      });

      try {
        context.read<AppStore?>()?.triggerNotificationChime();
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          backgroundColor: const Color(0xFF0F172A),
          content: Text(
            notif.summaryText,
            style: const TextStyle(
              color: Color(0xFFFDE68A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    unawaited(
      showBrowserLeaderNotification(
        title: '🏆 Óránkénti Kvíz Ranglista',
        body: notif.summaryText,
      ),
    );
    unawaited(
      LocalNotificationService.instance.showUnreadChatNotification(
        unreadCount: 1,
        title: '🏆 Óránkénti Kvíz Ranglista',
        body: notif.summaryText,
      ),
    );
  }

  Future<void> _checkHourlyLeaderDigest({required bool forceNow}) async {
    try {
      final res = await _repo.syncAndFetchHourlyNotifications(
        forceNow: forceNow,
      );
      if (!_initialNotifsSeeded) {
        _initialNotifsSeeded = true;
        for (final n in res.recent) {
          _seenNotificationIds.add(n.id);
        }
      }
      for (final emitted in res.newlyEmitted) {
        await _handleIncomingHourlyNotification(emitted);
      }
      if (mounted && res.recent.isNotEmpty) {
        setState(() {
          _hourlyNotifications = res.recent;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _hourlyCheckTimer?.cancel();
    if (_realtimeChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _repo.listEventsWithMetrics(),
        _repo.fetchCategoryStats(),
        _repo.syncAndFetchHourlyNotifications(forceNow: false),
      ]);
      if (!mounted) return;
      final notifBundle = results[2] as ({
        List<QuizHourlyNotification> recent,
        List<QuizHourlyNotification> newlyEmitted,
      });
      if (!_initialNotifsSeeded) {
        _initialNotifsSeeded = true;
        for (final n in notifBundle.recent) {
          _seenNotificationIds.add(n.id);
        }
      }
      setState(() {
        _events = results[0] as List<QuizEvent>;
        _categoryStats = results[1] as List<QuizCategoryStat>;
        _hourlyNotifications = notifBundle.recent;
        _loading = false;
      });
      for (final emitted in notifBundle.newlyEmitted) {
        await _handleIncomingHourlyNotification(emitted);
      }
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openCreateOrEditDialog({
    QuizEvent? existing,
    QuizEvent? templateFrom,
  }) async {
    final stats = _categoryStats.isNotEmpty
        ? _categoryStats
        : await _repo.fetchCategoryStats();
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _QuizEventFormDialog(
        repository: _repo,
        categoryStats: stats,
        existing: existing,
        templateFrom: templateFrom,
      ),
    );
    if (result == 'saved') {
      await _loadAll();
    } else if (result == 'request_delete' && existing != null) {
      await _confirmDelete(existing);
    }
  }

  Future<void> _toggleActive(QuizEvent ev, bool next) async {
    try {
      await _repo.toggleEventActive(ev.id, next);
      await _loadAll(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Állapotváltás sikertelen: $e')),
      );
    }
  }

  Future<void> _confirmDelete(QuizEvent ev) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: HunorColors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Esemény végleges törlése')),
          ],
        ),
        content: Text(
          'Biztosan törlöd a(z) „${ev.title}” (${ev.slug}) rendezvénykvízt az összes eddigi kitöltéssel (${ev.startedCount} db) és kuponkóddal együtt?\n\nA többi párhuzamosan futó eseményt a törlés nem érinti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mégse'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: HunorColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Esemény törlése'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteEvent(ev.id);
      if (!mounted) return;
      setState(() {
        _events = _events.where((x) => x.id != ev.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ A(z) „${ev.title}” esemény sikeresen törölve.'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
      await _loadAll(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Törlés sikertelen: $e')),
      );
    }
  }

  void _openQrPosterDialog(QuizEvent ev, {required bool isOnlineMode}) {
    showDialog<void>(
      context: context,
      builder: (_) => _PrintableQrPosterDialog(
        event: ev,
        repository: _repo,
        isOnlineMode: isOnlineMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore?>();
    final hasSession =
        Supabase.instance.client.auth.currentSession != null ||
            (store != null && store.isAuthenticated && !store.isGuest);

    if (store != null && store.initialized && !hasSession) {
      final denied = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'Szervezői bejelentkezés szükséges',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A Rendezvény kvízek kezeléséhez jelentkezz be szervezőként.',
                    textAlign: TextAlign.center,
                  ),
                  if (widget.onReturnToPortal != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: widget.onReturnToPortal,
                      child: const Text('Vissza a csapatportálra'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      return widget.embedded ? denied : Scaffold(body: denied);
    }

    final activeEventsCount = _events.where((e) => e.isActive).length;
    final inactiveEventsCount = _events.length - activeEventsCount;
    final visibleEvents = switch (_statusFilter) {
      _EventStatusFilter.all => _events,
      _EventStatusFilter.active => _events.where((e) => e.isActive).toList(),
      _EventStatusFilter.inactive => _events.where((e) => !e.isActive).toList(),
    };

    final anyRewardConfigured = _events.any((e) => e.hasConfiguredReward);
    final totalStarted =
        _events.fold<int>(0, (sum, e) => sum + e.startedCount);
    final totalCompleted =
        _events.fold<int>(0, (sum, e) => sum + e.completedCount);
    final totalAbandoned =
        _events.fold<int>(0, (sum, e) => sum + e.abandonedCount);
    final totalWinners =
        _events.fold<int>(0, (sum, e) => sum + e.winnersCount);
    final totalRedeemed =
        _events.fold<int>(0, (sum, e) => sum + e.redeemedCount);

    final content = RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SZERVEZŐI KEZELŐFELÜLET',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Rendezvény kvízek',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await showBrowserLeaderNotification(
                        title: '🏆 Óránkénti Kvíz Értesítések aktiválva',
                        body:
                            'Minden egész órában jelezni fogjuk, ki töltötte ki legjobban és leggyorsabban a kvízt!',
                      );
                      await _checkHourlyLeaderDigest(forceNow: true);
                    },
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: Color(0xFFFBBF24),
                    ),
                    label: const Text('Azonnali ranglista-értesítés'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadAll,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Frissítés'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openCreateOrEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Új rendezvénykvíz'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Live Aggregated Event Statistics (only show reward counters if at least one event configured a reward)
          LayoutBuilder(
            builder: (context, constraints) {
              final tileCount = anyRewardConfigured ? 5 : 3;
              final cols = constraints.maxWidth >= 960
                  ? tileCount
                  : (constraints.maxWidth >= 640 ? 3 : 2);
              final itemWidth =
                  (constraints.maxWidth - (cols - 1) * 10) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricTile(
                      label: 'Elkezdte (Megnyitások)',
                      value: '$totalStarted',
                      icon: Icons.play_circle_outline,
                      accent: const Color(0xFF38BDF8),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricTile(
                      label: 'Befejezte',
                      value: '$totalCompleted',
                      icon: Icons.task_alt_rounded,
                      accent: const Color(0xFF4ADE80),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricTile(
                      label: 'Félbehagyta',
                      value: '$totalAbandoned',
                      icon: Icons.trending_down_rounded,
                      accent: const Color(0xFFF59E0B),
                    ),
                  ),
                  if (anyRewardConfigured) ...[
                    SizedBox(
                      width: itemWidth,
                      child: _SummaryMetricTile(
                        label: 'Nyertesek',
                        value: '$totalWinners',
                        icon: Icons.emoji_events_outlined,
                        accent: const Color(0xFFA78BFA),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _SummaryMetricTile(
                        label: 'Nyeremény beváltása',
                        value: '$totalRedeemed',
                        icon: Icons.redeem_rounded,
                        accent: const Color(0xFFF43F5E),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Multi-Event Simultaneous Status Banner & Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: HunorColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activeEventsCount > 0
                    ? const Color(0xFF4ADE80).withValues(alpha: 0.4)
                    : Colors.white12,
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 20,
                      color: activeEventsCount > 0
                          ? const Color(0xFF4ADE80)
                          : HunorColors.muted,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Párhuzamosan futó (aktív) események: $activeEventsCount db',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'Egyszerre több rendezvénykvíz is futtatható külön QR-kóddal, saját PIN-nel és független statisztikával.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: HunorColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text('Összes (${_events.length})'),
                      selected: _statusFilter == _EventStatusFilter.all,
                      onSelected: (_) => setState(
                        () => _statusFilter = _EventStatusFilter.all,
                      ),
                    ),
                    ChoiceChip(
                      label: Text('Futó / Aktív ($activeEventsCount)'),
                      selected: _statusFilter == _EventStatusFilter.active,
                      onSelected: (_) => setState(
                        () => _statusFilter = _EventStatusFilter.active,
                      ),
                    ),
                    ChoiceChip(
                      label: Text('Szünetel ($inactiveEventsCount)'),
                      selected: _statusFilter == _EventStatusFilter.inactive,
                      onSelected: (_) => setState(
                        () => _statusFilter = _EventStatusFilter.inactive,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_hourlyNotifications.isNotEmpty) ...[
            _buildHourlyDigestBanner(_hourlyNotifications.first),
            const SizedBox(height: 14),
          ],

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Hiba a rendezvénykvízek betöltésekor:\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: HunorColors.muted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadAll,
                      child: const Text('Újrapróbálás'),
                    ),
                  ],
                ),
              ),
            )
          else if (_events.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 56,
                      color: HunorColors.muted,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Még nincs létrehozott rendezvénykvíz.',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hozz létre egy vagy több párhuzamosan futó eseményt (pl. Barcsi Adventi Vásár 2026), válaszd ki a kérdéskategóriákat, és töltsd le a nyomtatható QR-kódos plakátokat!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HunorColors.muted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openCreateOrEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Első rendezvénykvíz létrehozása'),
                    ),
                  ],
                ),
              ),
            )
          else if (visibleEvents.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    _statusFilter == _EventStatusFilter.active
                        ? 'Jelenleg nincs aktív (futó) esemény ebben a szűrésben.'
                        : 'Nincs szüneteltetett esemény ebben a szűrésben.',
                    style: const TextStyle(color: HunorColors.muted),
                  ),
                ),
              ),
            )
          else
            for (final ev in visibleEvents) ...[
              _buildEventCard(ev),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rendezvény kvízek'),
        leading: widget.onReturnToPortal == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Vissza a csapatportálra',
                onPressed: widget.onReturnToPortal,
              ),
      ),
      body: content,
    );
  }

  Widget _buildEventCard(QuizEvent ev) {
    return Card(
      color: HunorColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: ev.isActive
              ? const Color(0xFF4ADE80).withValues(alpha: 0.45)
              : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            ev.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ev.isActive
                                  ? const Color(0xFF15803D)
                                      .withValues(alpha: 0.3)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              ev.isActive ? '● AKTÍV' : '○ INAKTÍV',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: ev.isActive
                                    ? const Color(0xFF86EFAC)
                                    : HunorColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        ev.qrDeepLink,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          'Kérdésszám: ${ev.questionCount} db',
                          if (ev.requireParticipantName) 'Név megadása: kötelező',
                          if (ev.hourlyLeaderNotify) 'Óránkénti értesítés: BE',
                          if (ev.hasConfiguredReward)
                            'Nyeremény: ${ev.rewardName} (min. ${ev.minScore} pont) • PIN: ${ev.staffPin}',
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: HunorColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final cat in ev.selectedCategories)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                quizCategoryLabel(cat),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFBAE6FD),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: ev.isActive,
                  onChanged: (v) => _toggleActive(ev, v),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _pillMetric(
                  'Elkezdte (Megnyitások)',
                  '${ev.startedCount}',
                  const Color(0xFF38BDF8),
                ),
                _pillMetric(
                  'Befejezte',
                  '${ev.completedCount}',
                  const Color(0xFF4ADE80),
                ),
                _pillMetric(
                  'Félbehagyta',
                  '${ev.abandonedCount}',
                  const Color(0xFFF59E0B),
                ),
                if (ev.hasConfiguredReward) ...[
                  _pillMetric(
                    'Nyertesek',
                    '${ev.winnersCount}',
                    const Color(0xFFA78BFA),
                  ),
                  _pillMetric(
                    'Nyeremény beváltása',
                    '${ev.redeemedCount}',
                    const Color(0xFFF43F5E),
                  ),
                ],
              ],
            ),
            if (ev.topLeaders.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildEventLeaderboardPanel(ev),
            ],
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () =>
                      _openQrPosterDialog(ev, isOnlineMode: false),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Nyomtatható poszter'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      _openQrPosterDialog(ev, isOnlineMode: true),
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: const Text('Online megosztás (QR + link)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openCreateOrEditDialog(templateFrom: ev),
                  icon: const Icon(Icons.control_point_duplicate_rounded, size: 16),
                  label: const Text('Másolás'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openCreateOrEditDialog(existing: ev),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Szerkesztés'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HunorColors.red,
                    side: BorderSide(
                      color: HunorColors.red.withValues(alpha: 0.6),
                    ),
                  ),
                  onPressed: () => _confirmDelete(ev),
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    size: 18,
                    color: HunorColors.red,
                  ),
                  label: const Text(
                    'Esemény törlése',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillMetric(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyDigestBanner(QuizHourlyNotification latest) {
    final localTime = latest.createdAt.toLocal();
    final hh = localTime.hour.toString().padLeft(2, '0');
    final mm = localTime.minute.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF78350F).withValues(alpha: 0.45),
            HunorColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.55),
          width: 1.3,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFBBF24),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ÓRÁNKÉNTI RANGLISTA ÉRTESÍTÉS ($hh:$mm)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Color(0xFFFBBF24),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  latest.summaryText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventLeaderboardPanel(QuizEvent ev) {
    final top = ev.topLeaders.take(5).toList();
    final hourLeader = ev.lastHourLeader;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 18,
                    color: Color(0xFFFBBF24),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Legjobb & leggyorsabb kitöltők (pontszám + idő)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFDE68A),
                    ),
                  ),
                ],
              ),
              if (hourLeader != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    'Elmúlt 1 óra 1. hely: ${hourLeader.participantName} (${hourLeader.score}/${ev.questionCount} • ${hourLeader.formattedDuration})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFBAE6FD),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < top.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      i == 0
                          ? '🥇'
                          : i == 1
                              ? '🥈'
                              : i == 2
                                  ? '🥉'
                                  : '${i + 1}.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      top[i].participantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            i == 0 ? FontWeight.w900 : FontWeight.w600,
                        color: i == 0
                            ? const Color(0xFFFDE68A)
                            : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${top[i].score} / ${ev.questionCount} pont',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4ADE80),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⏱ ${top[i].formattedDuration}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFBAE6FD),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HunorColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: HunorColors.muted,
                  ),
                ),
              ),
              Icon(icon, size: 19, color: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CREATE / EDIT EVENT DIALOG WITH MULTI-SELECT 5-CATEGORY PICKER
// =============================================================================

class _QuizEventFormDialog extends StatefulWidget {
  const _QuizEventFormDialog({
    required this.repository,
    required this.categoryStats,
    this.existing,
    this.templateFrom,
  });

  final EventQuizRepository repository;
  final List<QuizCategoryStat> categoryStats;
  final QuizEvent? existing;
  final QuizEvent? templateFrom;

  @override
  State<_QuizEventFormDialog> createState() => _QuizEventFormDialogState();
}

class _QuizEventFormDialogState extends State<_QuizEventFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _qCount;
  late final TextEditingController _minScore;
  late final TextEditingController _rewardName;
  late final TextEditingController _staffPin;
  late final Set<String> _selectedCategories;
  late bool _requireParticipantName;
  late bool _hourlyLeaderNotify;
  late bool _rewardEnabled;
  late bool _isActive;
  bool _slugManuallyEdited = false;
  bool _saving = false;
  String? _saveError;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final t = widget.templateFrom;
    final src = e ?? t;
    final initialTitle = e != null
        ? e.title
        : (t != null ? '${t.title} – 2. helyszín' : '');
    final initialSlug = e != null
        ? e.slug
        : (t != null ? _slugify(initialTitle) : '');
    _title = TextEditingController(text: initialTitle);
    _slug = TextEditingController(text: initialSlug);
    _qCount = TextEditingController(text: '${src?.questionCount ?? 10}');
    _minScore = TextEditingController(text: '${src?.minScore ?? 8}');
    _rewardName = TextEditingController(
      text: src != null && src.hasConfiguredReward ? src.rewardName : '',
    );
    _staffPin = TextEditingController(text: src?.staffPin ?? '1234');
    _selectedCategories = src != null && src.selectedCategories.isNotEmpty
        ? src.selectedCategories.toSet()
        : {'altalanos'};
    _requireParticipantName = src?.requireParticipantName ?? true;
    _hourlyLeaderNotify = src?.hourlyLeaderNotify ?? true;
    _rewardEnabled = src?.hasConfiguredReward ?? false;
    _isActive = e?.isActive ?? true;
    _slugManuallyEdited = e != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _qCount.dispose();
    _minScore.dispose();
    _rewardName.dispose();
    _staffPin.dispose();
    super.dispose();
  }

  List<QuizCategoryStat> get _effectiveStats {
    if (widget.categoryStats.isNotEmpty) return widget.categoryStats;
    return const [
      QuizCategoryStat(category: 'altalanos', count: 58),
      QuizCategoryStat(category: 'advent', count: 10),
      QuizCategoryStat(category: 'teli_idojaras', count: 10),
      QuizCategoryStat(category: 'arviz_belviz', count: 10),
      QuizCategoryStat(category: 'szabadteri_tuz', count: 10),
    ];
  }

  int get _selectedPoolCount {
    var sum = 0;
    for (final stat in _effectiveStats) {
      if (_selectedCategories.contains(stat.category)) {
        sum += stat.count;
      }
    }
    return sum;
  }

  String _slugify(String raw) {
    const map = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ö': 'o',
      'ő': 'o',
      'ú': 'u',
      'ü': 'u',
      'ű': 'u',
    };
    var s = raw.toLowerCase();
    map.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    return s;
  }

  void _toggleCategory(String cat, bool selected) {
    setState(() {
      if (selected) {
        _selectedCategories.add(cat);
        _categoryError = null;
      } else {
        _selectedCategories.remove(cat);
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedCategories.isEmpty) {
      setState(() {
        _categoryError = 'Válassz ki legalább 1 kérdéskategóriát!';
      });
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;

    setState(() {
      _saving = true;
      _saveError = null;
      _categoryError = null;
    });

    try {
      final qCount = int.parse(_qCount.text.trim());
      final minScore = _rewardEnabled
          ? int.parse(_minScore.text.trim())
          : (int.tryParse(_minScore.text.trim()) ?? qCount).clamp(0, qCount);
      final orderedCats = [
        for (final s in _effectiveStats)
          if (_selectedCategories.contains(s.category)) s.category,
        for (final c in _selectedCategories)
          if (!_effectiveStats.any((s) => s.category == c)) c,
      ];

      if (widget.existing == null) {
        await widget.repository.createEvent(
          slug: _slug.text.trim().toLowerCase(),
          title: _title.text.trim(),
          selectedCategories: orderedCats,
          questionCount: qCount,
          minScore: minScore,
          rewardEnabled: _rewardEnabled,
          rewardName: _rewardName.text.trim(),
          requireParticipantName: _requireParticipantName,
          hourlyLeaderNotify: _hourlyLeaderNotify,
          staffPin: _staffPin.text.trim(),
          isActive: _isActive,
        );
      } else {
        await widget.repository.updateEvent(
          id: widget.existing!.id,
          slug: _slug.text.trim().toLowerCase(),
          title: _title.text.trim(),
          selectedCategories: orderedCats,
          questionCount: qCount,
          minScore: minScore,
          rewardEnabled: _rewardEnabled,
          rewardName: _rewardName.text.trim(),
          requireParticipantName: _requireParticipantName,
          hourlyLeaderNotify: _hourlyLeaderNotify,
          staffPin: _staffPin.text.trim(),
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, 'saved');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e.toString().contains('duplicate key')
            ? 'Ez a slug azonosító már foglalt! Válassz másikat.'
            : 'Mentési hiba: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final poolCount = _selectedPoolCount;

    return AlertDialog(
      title: Text(
        editing ? 'Rendezvénykvíz szerkesztése' : 'Új rendezvénykvíz létrehozása',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Rendezvény neve *',
                    hintText: 'pl. Barcsi Adventi Vásár 2026',
                  ),
                  onChanged: (v) {
                    if (!_slugManuallyEdited) {
                      _slug.text = _slugify(v);
                    }
                  },
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Add meg a rendezvény nevét!'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slug,
                  decoration: InputDecoration(
                    labelText: 'URL azonosító (slug) *',
                    hintText: 'pl. barcsi-adventi-vasar-2026',
                    suffixIcon: IconButton(
                      tooltip: 'Generálás a rendezvény nevéből',
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      onPressed: () => setState(() {
                        _slugManuallyEdited = false;
                        _slug.text = _slugify(_title.text);
                      }),
                    ),
                  ),
                  onChanged: (_) => _slugManuallyEdited = true,
                  validator: (v) {
                    final s = (v ?? '').trim().toLowerCase();
                    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{1,62}$').hasMatch(s)) {
                      return 'Csak kisbetű, szám és kötőjel (min. 2 karakter).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Multi-Select Category Picker (selected_categories)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kérdéskategóriák kiválasztása *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        'Kiválasztott kérdésbank: $poolCount kérdés',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFBAE6FD),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final stat in _effectiveStats)
                      FilterChip(
                        selected: _selectedCategories.contains(stat.category),
                        onSelected: (sel) => _toggleCategory(stat.category, sel),
                        selectedColor:
                            const Color(0xFFF59E0B).withValues(alpha: 0.28),
                        checkmarkColor: const Color(0xFFFBBF24),
                        label: Text(
                          '${stat.label} (${stat.count})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                _selectedCategories.contains(stat.category)
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_categoryError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _categoryError!,
                      style: const TextStyle(
                        color: HunorColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
                TextFormField(
                  controller: _qCount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kérdések száma *',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1) {
                      return 'Min. 1 kérdés';
                    }
                    if (poolCount > 0 && n > poolCount) {
                      return 'Max. $poolCount kérdés';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _requireParticipantName,
                  title: const Text(
                    'Kitöltő nevének bekérése (kötelező)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'A kvíz indítása előtt meg kell adnia a nevét annak, aki kitölti.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) => setState(() => _requireParticipantName = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _hourlyLeaderNotify,
                  title: const Text(
                    'Óránkénti legjobb & leggyorsabb értesítés adminnak',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Minden órában jelzi az adminnak, ki érte el a legtöbb pontot a leggyorsabb idő alatt.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) => setState(() => _hourlyLeaderNotify = v),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _rewardEnabled,
                  title: const Text(
                    'Kuponos díjazás bekapcsolása (opcionális)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Alapból kikapcsolva. Csak akkor kapcsold be, ha beváltható tételt szeretnél adni.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (v) => setState(() => _rewardEnabled = v),
                ),
                if (_rewardEnabled) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _rewardName,
                    decoration: const InputDecoration(
                      labelText: 'Nyeremény megnevezése (szabadon begépelhető) *',
                      hintText: 'pl. egy üdítő, egy strandbelépő...',
                    ),
                    validator: (v) =>
                        (_rewardEnabled && (v == null || v.trim().isEmpty))
                            ? 'Add meg, mi legyen a nyeremény!'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minScore,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min. pont nyereményhez *',
                          ),
                          validator: (v) {
                            if (!_rewardEnabled) return null;
                            final n = int.tryParse((v ?? '').trim());
                            final maxQ =
                                int.tryParse(_qCount.text.trim()) ?? 10;
                            if (n == null || n < 0 || n > maxQ) {
                              return '0–$maxQ közötti';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _staffPin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Személyzeti PIN kód *',
                          ),
                          validator: (v) =>
                              (_rewardEnabled && (v == null || v.trim().isEmpty))
                                  ? 'Add meg a PIN kódot!'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text('Rendezvénykvíz aktív (fogad kitöltéseket)'),
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _saveError!,
                      style:
                          const TextStyle(color: HunorColors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: HunorColors.red),
            onPressed:
                _saving ? null : () => Navigator.pop(context, 'request_delete'),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Esemény törlése'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, 'cancel'),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Mentés…' : 'Mentés'),
        ),
      ],
    );
  }
}

// =============================================================================
// PRINTABLE QR POSTER DIALOG (RESCUE TEAM ILLUSTRATED POSTER TEMPLATE)
// =============================================================================

class _PrintableQrPosterDialog extends StatefulWidget {
  const _PrintableQrPosterDialog({
    required this.event,
    required this.repository,
    required this.isOnlineMode,
  });

  final QuizEvent event;
  final EventQuizRepository repository;
  final bool isOnlineMode;

  @override
  State<_PrintableQrPosterDialog> createState() =>
      _PrintableQrPosterDialogState();
}

class _PrintableQrPosterDialogState extends State<_PrintableQrPosterDialog> {
  static const String _bgAssetPath = 'assets/images/quiz_poster_bg.jpg';

  final GlobalKey _posterBoundaryKey = GlobalKey();
  bool _exporting = false;
  bool _sharing = false;
  bool _bgPrecached = false;
  bool _cloudSynced = false;
  late bool _onlineMode = widget.isOnlineMode;

  @override
  void initState() {
    super.initState();
    // Automatically publish the rendered poster to public Storage so Facebook renders the full clickable poster card!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 350), _syncPosterToCloudSilently);
    });
  }

  Future<void> _syncPosterToCloudSilently() async {
    if (!mounted || _cloudSynced) return;
    try {
      final pngBytes = await _capturePosterPngBytes(pixelRatio: 2.5);
      final uploaded = await widget.repository.uploadPublicPosterImage(
        slug: widget.event.slug,
        pngBytes: pngBytes,
      );
      if (uploaded != null && mounted) {
        setState(() => _cloudSynced = true);
      }
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bgPrecached) {
      _bgPrecached = true;
      precacheImage(const AssetImage(_bgAssetPath), context);
    }
  }

  Future<Uint8List> _capturePosterPngBytes({double pixelRatio = 3.5}) async {
    await precacheImage(const AssetImage(_bgAssetPath), context);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final boundary = _posterBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('A plakát előnézet nem érhető el.');
    }

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('A PNG képfájl előállítása nem sikerült.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _shareClickableCardToFacebook() async {
    if (_sharing || _exporting) return;
    setState(() => _sharing = true);
    try {
      if (!_cloudSynced) {
        final pngBytes = await _capturePosterPngBytes(pixelRatio: 2.5);
        await widget.repository.uploadPublicPosterImage(
          slug: widget.event.slug,
          pngBytes: pngBytes,
        );
        _cloudSynced = true;
      }
      final url = widget.event.qrDeepLink;
      await Clipboard.setData(ClipboardData(text: url));
      final fbShare = Uri.parse(
        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}&quote=${Uri.encodeComponent('${widget.event.title} – Kattints a poszterre és töltsd ki a Vészhelyzeti kvízt!')}',
      );
      await launchUrl(fbShare, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 6),
          content: Text(
            '✓ Facebook megosztó megnyitva! A poszterkép egyetlen nagy KATTINTHATÓ kártyaként jelenik meg (a link a vágólapra is került)!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Facebook megosztási hiba: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _downloadPosterPng() async {
    if (_exporting || _sharing) return;
    setState(() => _exporting = true);
    try {
      final pngBytes = await _capturePosterPngBytes();
      final ok = downloadPngBytes(
        pngBytes,
        'hunor-plakat-${widget.event.slug}.png',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '✓ Nyomtatható plakát letöltve (hunor-plakat-${widget.event.slug}.png)!'
                : 'A PNG letöltés webes böngészőben érhető el.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plakát letöltési hiba: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _copyPosterImageForFacebook() async {
    if (_sharing || _exporting) return;
    setState(() => _sharing = true);
    try {
      final pngBytes = await _capturePosterPngBytes();
      final copied = await copySinglePosterImageToClipboard(pngBytes);
      if (!mounted) return;
      if (copied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              '✓ Poszterkép vágólapra másolva (1 db tiszta PNG)! Facebookon nyomj Beillesztést (Ctrl+V / Cmd+V) – nem fog duplikálódni!',
            ),
          ),
        );
      } else {
        downloadPngBytes(
          pngBytes,
          'veszhelyzeti-kviz-${widget.event.slug}.png',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A böngésző nem engedélyezte a kép vágólapra írását, ezért letöltöttük PNG-ben.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Képmásolási hiba: $e')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _openQuizLinkDirectly() async {
    final uri = Uri.tryParse(widget.event.qrDeepLink);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildDynamicPosterTitle(String rawTitle) {
    final cleaned = rawTitle.trim().toUpperCase();
    final words = cleaned.isEmpty
        ? <String>['VÉSZHELYZETI', 'KVÍZ']
        : cleaned.split(RegExp(r'\s+'));

    final hasTrailingYear =
        words.length >= 2 && RegExp(r'^\d{4}$').hasMatch(words.last);

    // Split words cleanly across 1 or 2 lines like "BARCS ADVENTI" / "VÁSÁR 2026"
    late final List<String> line1Words;
    late final List<String> line2Words;
    if (words.length <= 2) {
      line1Words = words;
      line2Words = const [];
    } else if (words.length == 3) {
      line1Words = words.sublist(0, 2);
      line2Words = words.sublist(2);
    } else {
      final splitAt = (words.length / 2).ceil();
      line1Words = words.sublist(0, splitAt);
      line2Words = words.sublist(splitAt);
    }

    const baseStyle = TextStyle(
      fontSize: 33,
      fontWeight: FontWeight.w900,
      height: 1.08,
      letterSpacing: 0.9,
      shadows: [
        Shadow(
          color: Color(0xE6040911),
          offset: Offset(0, 3),
          blurRadius: 10,
        ),
        Shadow(
          color: Color(0x99000000),
          offset: Offset(0, 1),
          blurRadius: 3,
        ),
      ],
    );

    Color colorForWord(int globalIndex) {
      if (hasTrailingYear && globalIndex == words.length - 1) {
        return const Color(0xFFF3C35F); // Warm metallic gold for year
      }
      if (words.length >= 2 && globalIndex == 1) {
        return const Color(0xFFEF5B16); // Vibrant rescue orange accent
      }
      return Colors.white;
    }

    Widget buildLine(List<String> lineWords, int startIndex) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: baseStyle,
            children: [
              for (var i = 0; i < lineWords.length; i++)
                TextSpan(
                  text: i == 0 ? lineWords[i] : ' ${lineWords[i]}',
                  style: TextStyle(color: colorForWord(startIndex + i)),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildLine(line1Words, 0),
        if (line2Words.isNotEmpty) ...[
          const SizedBox(height: 2),
          buildLine(line2Words, line1Words.length),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.event.qrDeepLink;

    return AlertDialog(
      title: Text(
        _onlineMode
            ? 'Online megosztás (QR + link) – ${widget.event.title}'
            : 'Nyomtatható poszter – ${widget.event.title}',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clean 2-way switcher at the top so the user can also flip between Print vs Online anytime
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.print_rounded, size: 18),
                  label: Text('Nyomtatható poszter'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.share_rounded, size: 18),
                  label: Text('Online (QR + link)'),
                ),
              ],
              selected: {_onlineMode},
              onSelectionChanged: (s) => setState(() => _onlineMode = s.first),
            ),
            const SizedBox(height: 14),
            MouseRegion(
              cursor:
                  _onlineMode ? SystemMouseCursors.click : MouseCursor.defer,
              child: GestureDetector(
                onTap: _onlineMode ? _openQuizLinkDirectly : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x77000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RepaintBoundary(
                    key: _posterBoundaryKey,
                    child: SizedBox(
                      width: 448,
                      height: 600,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Clean reusable illustrated rescue team background
                          Image.asset(
                            _bgAssetPath,
                            width: 448,
                            height: 600,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),

                      // Subtle top & bottom readability vignette (preserves heroes & stripes)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 18,
                        height: 170,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF0D1622).withValues(alpha: 0.45),
                                  const Color(0xFF0D1622).withValues(alpha: 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. Top Orange Pill Badge: [?] VÉSZHELYZETI KVÍZ
                      Positioned(
                        top: 36,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFD94A12),
                                  Color(0xFFEA580C),
                                  Color(0xFFD94A12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFFFB07A).withValues(alpha: 0.55),
                                width: 1.1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x99000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: Color(0x55EA580C),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.quiz_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'VÉSZHELYZETI KVÍZ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 3. Dynamic Multi-Tone Event Title + Glowing Laser Flare
                      Positioned(
                        top: 78,
                        left: 24,
                        right: 24,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 82),
                              child: _buildDynamicPosterTitle(widget.event.title),
                            ),
                            const SizedBox(height: 10),
                            // Glowing orange-gold horizontal laser flare
                            SizedBox(
                              width: 250,
                              height: 6,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    height: 2.2,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Color(0xFFEA580C),
                                          Color(0xFFFDE68A),
                                          Color(0xFFEA580C),
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xCCF59E0B),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 44,
                                    height: 3.5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0xFFFBBF24),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 4. Right-Side Dark Frosted Callout Card (with orange left tab)
                      Positioned(
                        top: 208,
                        right: 22,
                        width: 222,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Left orange accent shoulder
                            Positioned(
                              left: -4,
                              top: 8,
                              bottom: 22,
                              width: 10,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 5,
                                  sigmaY: 5,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xDD111B27),
                                        Color(0xCC1B2634),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.26),
                                      width: 1.1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x88000000),
                                        blurRadius: 14,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        height: 1.32,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Color(0xAA000000),
                                            offset: Offset(0, 1),
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _onlineMode
                                              ? 'Olvasd be a QR-kódot,\nvagy kattints a linkre,\n'
                                              : 'Olvasd be a QR-kódot,\ntöltsd ki a kvízt, és\n',
                                        ),
                                        TextSpan(
                                          text: _onlineMode
                                              ? 'és töltsd ki a kvízt!'
                                              : 'tegyél egy próbát!',
                                          style: const TextStyle(
                                            color: Color(0xFFF5B841),
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 5. Glowing White/Orange QR Card + Bottom Camera Pill
                      Positioned(
                        top: 332,
                        right: 34,
                        width: 192,
                        height: 202,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            Container(
                              width: 188,
                              height: 188,
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFF97316),
                                  width: 3.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xAAEA580C),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: Color(0xAA000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: QrImageView(
                                  data: url,
                                  version: QrVersions.auto,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  padding: const EdgeInsets.all(2),
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF0B111A),
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Color(0xFF0B111A),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 4.5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD94A12),
                                      Color(0xFFEA580C),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFFFC08E)
                                        .withValues(alpha: 0.6),
                                    width: 0.9,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x99000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.smartphone_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'IRÁNYÍTSD RÁ A KAMERÁD!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.6,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 6. Bottom Feature Strip (+ Online Link Pill ONLY in Online Mode!)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: _onlineMode ? 19 : 25,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 12.6,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Color(0xDD000000),
                                        offset: Offset(0, 1.5),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${widget.event.questionCount} gyors kérdés',
                                    ),
                                    const TextSpan(
                                      text: ' • ',
                                      style: TextStyle(
                                        color: Color(0xFFF5B841),
                                      ),
                                    ),
                                    const TextSpan(
                                      text: 'Azonnali',
                                      style: TextStyle(
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                    const TextSpan(text: ' magyarázat'),
                                    const TextSpan(
                                      text: ' • ',
                                      style: TextStyle(
                                        color: Color(0xFFF5B841),
                                      ),
                                    ),
                                    const TextSpan(
                                      text: 'Regisztráció nélkül',
                                      style: TextStyle(
                                        color: Color(0xFFEF5B16),
                                      ),
                                    ),
                                    const TextSpan(text: '!'),
                                  ],
                                ),
                              ),
                            ),
                            if (_onlineMode) ...[
                              const SizedBox(height: 5),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xD90F172A),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.65),
                                      width: 1.1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.link_rounded,
                                        size: 13,
                                        color: Color(0xFF38BDF8),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        url,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.8,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 5),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  url,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF8CA0B6),
                                    fontSize: 9.8,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                ),
              ),
            ),
            if (_onlineMode) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 448,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HunorColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: _openQuizLinkDirectly,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                size: 17,
                                color: Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  url,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF38BDF8),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '💡 Facebookra: kattints a „Facebookra posztolás” gombra (vagy csak másold be a linket külön kép feltöltése nélkül) – így a teljes poszterkép KATTINTHATÓ lesz a Facebookon!',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Color(0xFFBAE6FD),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                if (!_cloudSynced) {
                                  await _syncPosterToCloudSilently();
                                }
                                await Clipboard.setData(
                                  ClipboardData(text: url),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    duration: Duration(seconds: 6),
                                    content: Text(
                                      '✓ Kattintható poszter-link vágólapra másolva! Illeszd be Facebookra (kép feltöltése nélkül), és a poszter kattintható kártyaként jelenik meg!',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.link_rounded,
                                size: 16,
                              ),
                              label: const Text('Kattintható link másolása'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_sharing || _exporting)
                                  ? null
                                  : _copyPosterImageForFacebook,
                              icon: const Icon(Icons.image_outlined, size: 16),
                              label: const Text('Csak kép másolása'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bezárás'),
        ),
        if (_onlineMode)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
            ),
            onPressed:
                (_sharing || _exporting) ? null : _shareClickableCardToFacebook,
            icon: _sharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.facebook_rounded),
            label: const Text('Facebookra posztolás (kattintható poszter)'),
          )
        else
          FilledButton.icon(
            onPressed: (_exporting || _sharing) ? null : _downloadPosterPng,
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_rounded),
            label: const Text('Nyomtatható poszter letöltése (PNG)'),
          ),
      ],
    );
  }
}
