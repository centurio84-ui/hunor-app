import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/app_store.dart';
import '../../theme/hunor_theme.dart';
import 'device_hash_helper.dart';
import 'event_quiz_models.dart';
import 'event_quiz_repository.dart';

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
  Timer? _pollTimer;
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
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
      ]);
      if (!mounted) return;
      setState(() {
        _events = results[0] as List<QuizEvent>;
        _categoryStats = results[1] as List<QuizCategoryStat>;
        _loading = false;
      });
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

  Future<void> _openCreateOrEditDialog([QuizEvent? existing]) async {
    final stats = _categoryStats.isNotEmpty
        ? _categoryStats
        : await _repo.fetchCategoryStats();
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _QuizEventFormDialog(
        repository: _repo,
        categoryStats: stats,
        existing: existing,
      ),
    );
    if (saved == true) {
      await _loadAll();
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
        title: const Text('Rendezvénykvíz törlése'),
        content: Text(
          'Biztosan törlöd a(z) „${ev.title}” (${ev.slug}) rendezvényt az összes eddigi kitöltéssel együtt?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HunorColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteEvent(ev.id);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Törlés sikertelen: $e')),
      );
    }
  }

  void _openQrPosterDialog(QuizEvent ev) {
    showDialog<void>(
      context: context,
      builder: (_) => _PrintableQrPosterDialog(event: ev),
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
                    'Rendezvény kvízek & Kürtőskalács kuponok',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadAll,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Frissítés'),
                  ),
                  const SizedBox(width: 10),
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

          // Live Aggregated Event Statistics (5 counters)
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 960
                  ? 5
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
                      label: 'Beváltott kürtöskalács',
                      value: '$totalRedeemed',
                      icon: Icons.bakery_dining_rounded,
                      accent: const Color(0xFFF43F5E),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

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
                      'Hozz létre egy eseményt (pl. Barcsi Adventi Vásár 2026), válaszd ki a kérdéskategóriákat, és töltsd le a nyomtatható QR-kódos plakátot!',
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
          else
            for (final ev in _events) ...[
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
                        'Kérdésszám: ${ev.questionCount} db • Nyereményhatár: min. ${ev.minScore} pont • Személyzeti PIN: ${ev.staffPin}',
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
                _pillMetric(
                  'Nyertesek',
                  '${ev.winnersCount}',
                  const Color(0xFFA78BFA),
                ),
                _pillMetric(
                  'Beváltott kürtöskalács',
                  '${ev.redeemedCount}',
                  const Color(0xFFF43F5E),
                ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: ev.qrDeepLink));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kvíz link vágólapra másolva!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Link másolása'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openQrPosterDialog(ev),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('QR kód & Nyomtatható plakát'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openCreateOrEditDialog(ev),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Szerkesztés'),
                ),
                IconButton(
                  tooltip: 'Törlés',
                  onPressed: () => _confirmDelete(ev),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: HunorColors.red,
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
  });

  final EventQuizRepository repository;
  final List<QuizCategoryStat> categoryStats;
  final QuizEvent? existing;

  @override
  State<_QuizEventFormDialog> createState() => _QuizEventFormDialogState();
}

class _QuizEventFormDialogState extends State<_QuizEventFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _qCount;
  late final TextEditingController _minScore;
  late final TextEditingController _staffPin;
  late final Set<String> _selectedCategories;
  late bool _isActive;
  bool _slugManuallyEdited = false;
  bool _saving = false;
  String? _saveError;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _qCount = TextEditingController(text: '${e?.questionCount ?? 10}');
    _minScore = TextEditingController(text: '${e?.minScore ?? 8}');
    _staffPin = TextEditingController(text: e?.staffPin ?? '1234');
    _selectedCategories = e != null && e.selectedCategories.isNotEmpty
        ? e.selectedCategories.toSet()
        : {'altalanos'};
    _isActive = e?.isActive ?? true;
    _slugManuallyEdited = e != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _qCount.dispose();
    _minScore.dispose();
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
      final minScore = int.parse(_minScore.text.trim());
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
          staffPin: _staffPin.text.trim(),
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
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
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minScore,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min. pont kürtőskalácshoz *',
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          final maxQ = int.tryParse(_qCount.text.trim()) ?? 10;
                          if (n == null || n < 0 || n > maxQ) {
                            return '0–$maxQ közötti';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _staffPin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Személyzeti PIN kód (staff_pin) *',
                    helperText:
                        '4 jegyű PIN kód a kürtőskalács kupon helyszíni beváltásához.',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Add meg a személyzeti PIN kódot!'
                      : null,
                ),
                const SizedBox(height: 8),
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
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
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
// PRINTABLE QR POSTER DIALOG (USING RepaintBoundary + qr_flutter + MAD MASCOT)
// =============================================================================

class _PrintableQrPosterDialog extends StatefulWidget {
  const _PrintableQrPosterDialog({required this.event});

  final QuizEvent event;

  @override
  State<_PrintableQrPosterDialog> createState() =>
      _PrintableQrPosterDialogState();
}

class _PrintableQrPosterDialogState extends State<_PrintableQrPosterDialog> {
  final GlobalKey _posterBoundaryKey = GlobalKey();
  bool _exporting = false;

  Future<void> _downloadPosterPng() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      // Allow a frame settle so RepaintBoundary has painted all assets cleanly
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final boundary = _posterBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('A plakát előnézet nem érhető el.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('A PNG képfájl előállítása nem sikerült.');
      }

      final pngBytes = byteData.buffer.asUint8List();
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

  @override
  Widget build(BuildContext context) {
    final url = widget.event.qrDeepLink;

    return AlertDialog(
      title: Text('Nyomtatható QR plakát – ${widget.event.title}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Print-ready card captured via RepaintBoundary
            RepaintBoundary(
              key: _posterBoundaryKey,
              child: Container(
                width: 420,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HUNOR Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      color: const Color(0xFFB42530),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset(
                              'assets/images/hunor_badge.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.shield,
                                color: Color(0xFFB42530),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Text(
                              'HUNOR • VÉSZHELYZETI KVÍZ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                      child: Column(
                        children: [
                          // Event Title
                          Text(
                            widget.event.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // MAD Mascot + Callout
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/mad_chief.png',
                                height: 96,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.engineering_rounded,
                                  size: 64,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Text(
                                    'Olvasd be, töltsd ki a kvízt, és nyerj egy friss kürtöskalácsot!',
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      color: Color(0xFF78350F),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Large High-Res QR Code
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF0F172A),
                                width: 2.5,
                              ),
                            ),
                            child: QrImageView(
                              data: url,
                              version: QrVersions.auto,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                              size: 240,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF0F172A),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            'Minimum ${widget.event.minScore} / ${widget.event.questionCount} helyes válasz = azonnali kürtőskalács kupon!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFB42530),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            url,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bezárás'),
        ),
        FilledButton.icon(
          onPressed: _exporting ? null : _downloadPosterPng,
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: const Text('Nyomtatható plakát letöltése (PNG)'),
        ),
      ],
    );
  }
}
