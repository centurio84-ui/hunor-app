import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    // Auto-refresh live metrics every 10 seconds
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadMetrics(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMetrics({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await _repo.listEventsWithMetrics();
      if (!mounted) return;
      setState(() {
        _events = list;
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _QuizEventFormDialog(
        repository: _repo,
        existing: existing,
      ),
    );
    if (saved == true) {
      await _loadMetrics();
    }
  }

  Future<void> _toggleActive(QuizEvent ev, bool next) async {
    try {
      await _repo.toggleEventActive(ev.id, next);
      await _loadMetrics(silent: true);
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
        title: const Text('Kvíz-esemény törlése'),
        content: Text(
          'Biztosan törlöd a(z) „${ev.title}” (${ev.slug}) eseményt az összes eddigi kitöltéssel együtt?',
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
      await _loadMetrics();
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
      builder: (_) => _PrintableQrDialog(event: ev),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore?>();
    if (store != null && store.initialized && !store.isAdmin) {
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
                    'Csak adminisztrátoroknak',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A Rendezvény QR Kvíz kezelőfelületéhez adminisztrátori jogosultság szükséges.',
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
    final totalDropOff = (totalStarted - totalCompleted).clamp(0, totalStarted);
    final totalDropRate =
        totalStarted <= 0 ? 0.0 : (totalDropOff / totalStarted) * 100.0;
    final totalRedeemed =
        _events.fold<int>(0, (sum, e) => sum + e.redeemedCount);

    final content = RefreshIndicator(
      onRefresh: _loadMetrics,
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
                    'RENDEZVÉNY QR KVÍZ KEZELŐ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Event Quiz Manager & Élő Analitika',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _loadMetrics,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Frissítés'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _openCreateOrEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Új QR Kvíz-esemény'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Live Summary Metrics Row
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 760 ? 4 : 2;
              final itemWidth =
                  (constraints.maxWidth - (cols - 1) * 10) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricTile(
                      label: 'Elindított (Started)',
                      value: '$totalStarted',
                      icon: Icons.play_circle_outline,
                      accent: const Color(0xFF38BDF8),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricTile(
                      label: 'Befejezett (Completed)',
                      value: '$totalCompleted',
                      icon: Icons.task_alt_rounded,
                      accent: const Color(0xFF4ADE80),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricTile(
                      label: 'Lemorzsolódás (Drop-off)',
                      value: '${totalDropRate.toStringAsFixed(1)}%',
                      subtitle: '$totalDropOff félbehagyott',
                      icon: Icons.trending_down_rounded,
                      accent: const Color(0xFFF59E0B),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _SummaryMetricTile(
                      label: 'Beváltott díj (Redeemed)',
                      value: '$totalRedeemed',
                      icon: Icons.redeem_rounded,
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
                      'Hiba a kvíz-események betöltésekor:\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: HunorColors.muted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadMetrics,
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
                      'Még nincs létrehozott QR kvíz-esemény.',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hozz létre egy eseményt (pl. nyílt nap, fesztivál, konferencia), és töltsd le hozzá a nyomtatható nagy felbontású QR-kódot!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HunorColors.muted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openCreateOrEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Első esemény létrehozása'),
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
        title: const Text('Rendezvény QR Kvíz Kezelő'),
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
                      const SizedBox(height: 4),
                      Text(
                        'Kérdésszám: ${ev.questionCount} db • Nyereményhatár: min. ${ev.minScore} pont • Staff PIN: ${ev.staffPin}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: HunorColors.muted,
                        ),
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
                _pillMetric('Elindult', '${ev.startedCount}',
                    const Color(0xFF38BDF8)),
                _pillMetric('Befejezett', '${ev.completedCount}',
                    const Color(0xFF4ADE80)),
                _pillMetric(
                  'Drop-off arány',
                  '${ev.dropOffRatePercent.toStringAsFixed(1)}% (${ev.dropOffCount})',
                  const Color(0xFFF59E0B),
                ),
                _pillMetric('Nyertes kód', '${ev.qualifiedCount}',
                    const Color(0xFFA78BFA)),
                _pillMetric('Beváltott díj', '${ev.redeemedCount}',
                    const Color(0xFFF43F5E)),
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
                      const SnackBar(content: Text('Kvíz link vágólapra másolva!')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Link másolása'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openQrPosterDialog(ev),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Nyomtatható QR kód'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openCreateOrEditDialog(ev),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Szerkesztés'),
                ),
                IconButton(
                  tooltip: 'Törlés',
                  onPressed: () => _confirmDelete(ev),
                  icon: const Icon(Icons.delete_outline, color: HunorColors.red),
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
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 20, color: accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 11, color: HunorColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizEventFormDialog extends StatefulWidget {
  const _QuizEventFormDialog({
    required this.repository,
    this.existing,
  });

  final EventQuizRepository repository;
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
  late bool _isActive;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _qCount = TextEditingController(text: '${e?.questionCount ?? 10}');
    _minScore = TextEditingController(text: '${e?.minScore ?? 7}');
    _staffPin = TextEditingController(text: e?.staffPin ?? '1234');
    _isActive = e?.isActive ?? true;
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final qCount = int.parse(_qCount.text.trim());
      final minScore = int.parse(_minScore.text.trim());
      if (widget.existing == null) {
        await widget.repository.createEvent(
          slug: _slug.text.trim().toLowerCase(),
          title: _title.text.trim(),
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
    return AlertDialog(
      title: Text(editing ? 'QR Kvíz-esemény szerkesztése' : 'Új QR Kvíz-esemény'),
      content: SizedBox(
        width: 440,
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
                    labelText: 'Rendezvény / Esemény neve *',
                    hintText: 'pl. HUNOR Nyílt Nap 2026',
                  ),
                  onChanged: (v) {
                    if (!editing && _slug.text.trim().isEmpty) {
                      _slug.text = _slugify(v);
                    }
                  },
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Add meg az esemény nevét!'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _slug,
                  decoration: InputDecoration(
                    labelText: 'URL azonosító (slug) *',
                    hintText: 'pl. nyilt-nap-2026',
                    suffixIcon: IconButton(
                      tooltip: 'Generálás a névből',
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      onPressed: () =>
                          setState(() => _slug.text = _slugify(_title.text)),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim().toLowerCase();
                    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{1,62}$').hasMatch(s)) {
                      return 'Csak kisbetű, szám, kötőjel (min. 2 karakter).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                          if (n == null || n < 1 || n > 50) {
                            return '1–50 közötti szám';
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
                          labelText: 'Min. pont díjhoz *',
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
                  decoration: const InputDecoration(
                    labelText: 'Személyzeti PIN kód (staff_pin) *',
                    helperText:
                        'Ezzel a PIN kóddal váltja be a stand személyzete a nyereményt.',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Add meg a személyzeti PIN kódot!'
                      : null,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text('Esemény aktív (fogad kitöltéseket)'),
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _saveError!,
                      style: const TextStyle(color: HunorColors.red, fontSize: 12),
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

class _PrintableQrDialog extends StatefulWidget {
  const _PrintableQrDialog({required this.event});

  final QuizEvent event;

  @override
  State<_PrintableQrDialog> createState() => _PrintableQrDialogState();
}

class _PrintableQrDialogState extends State<_PrintableQrDialog> {
  bool _exporting = false;

  Future<void> _downloadHighResPng() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final url = widget.event.qrDeepLink;

      // Render a crisp 2048×2480 printable poster PNG using QrPainter (from qr_flutter)
      const double width = 2048;
      const double height = 2480;
      const double qrSize = 1560;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // White printable background
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.white,
      );

      // Top red header bar
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width, 240),
        Paint()..color = const Color(0xFFB42530),
      );

      _drawCenteredText(
        canvas,
        'HUNOR • VÉSZHELYZETI KVÍZ',
        width / 2,
        85,
        const TextStyle(
          color: Colors.white,
          fontSize: 64,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
        width - 120,
      );

      _drawCenteredText(
        canvas,
        widget.event.title,
        width / 2,
        320,
        const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 78,
          fontWeight: FontWeight.w900,
        ),
        width - 160,
      );

      // High-res QR code via QrPainter from qr_flutter
      final qrPainter = QrPainter(
        data: url,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0F172A),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0F172A),
        ),
      );

      canvas.save();
      canvas.translate((width - qrSize) / 2, 500);
      qrPainter.paint(canvas, const Size(qrSize, qrSize));
      canvas.restore();

      _drawCenteredText(
        canvas,
        'Olvasd be a QR-kódot a játékhoz és a nyereménykódért!',
        width / 2,
        2140,
        const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 52,
          fontWeight: FontWeight.w700,
        ),
        width - 140,
      );

      _drawCenteredText(
        canvas,
        url,
        width / 2,
        2260,
        const TextStyle(
          color: Color(0xFF475569),
          fontSize: 38,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
        width - 140,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('PNG generálás sikertelen.');

      final pngBytes = byteData.buffer.asUint8List();
      final ok = downloadPngBytes(
        pngBytes,
        'hunor-qr-quiz-${widget.event.slug}.png',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '✓ Nagy felbontású (2048×2480 px) QR plakát letöltve!'
                : 'A PNG letöltés a webes felületen érhető el.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR letöltési hiba: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    double centerX,
    double topY,
    TextStyle style,
    double maxWidth,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(centerX - tp.width / 2, topY));
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.event.qrDeepLink;
    return AlertDialog(
      title: Text('Nyomtatható QR-kód – ${widget.event.title}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                size: 260,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              url,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'A letöltött PNG fájl 2048×2480 px nyomdai felbontású plakát fejléccel és felirattal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: HunorColors.muted),
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
          onPressed: _exporting ? null : _downloadHighResPng,
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: const Text('Nagy felbontású PNG letöltése'),
        ),
      ],
    );
  }
}
