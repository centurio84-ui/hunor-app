import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/api_error.dart';
import '../models/rescue_alert.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final active = s.alerts.where((a) => a.isActive).toList();
    final archived = s.alerts.where((a) => !a.isActive).toList();
    final canDispatch = s.isAdmin || (s.currentMembership?.hasPermission('alerts.dispatch') ?? false) || !s.isGuest;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canDispatch
          ? FloatingActionButton.extended(
              backgroundColor: HunorColors.exercise,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text('Próbariasztás', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _openCreateAlertSheet(context, s),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: s.loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          children: [
            if (canDispatch) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: HunorColors.exercise.withOpacity(0.4)),
                ),
                color: HunorColors.surface1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HunorColors.exercise.withAlpha(35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: HunorColors.exercise, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ADMINISZTRÁTORI PRÓBARIASZTÁS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: HunorColors.exercise,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Próbariasztást küldhetsz a tesztelőknek és a csapatnak.',
                              style: TextStyle(fontSize: 12, color: HunorColors.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: HunorColors.exercise,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () => _openCreateAlertSheet(context, s),
                        child: const Text('＋ Indítás', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (active.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'AKTÍV RIASZTÁSOK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: HunorColors.red,
                  ),
                ),
              ),
              ...active.map((a) => _AlertCard(alert: a)),
            ] else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: HunorColors.success, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Jelenleg nincs aktív riasztás ebben a szervezetben.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (archived.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
                child: Text(
                  'KORÁBBI VAGY LEJÁRT RIASZTÁSOK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: HunorColors.muted,
                  ),
                ),
              ),
              ...archived.map((a) => _AlertCard(alert: a, muted: true)),
            ],
          ],
        ),
      ),
    );
  }

  void _openCreateAlertSheet(BuildContext context, AppStore s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: HunorColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreateAlertDialog(store: s),
    );
  }
}
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: HunorColors.muted,
                ),
              ),
            ),
            ...archived.map((a) => _AlertCard(alert: a, muted: true)),
          ],
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final RescueAlert alert;
  final bool muted;

  const _AlertCard({
    required this.alert,
    this.muted = false,
  });

  Color get accent => switch (alert.type) {
        'exercise' => HunorColors.exercise,
        'standby' => HunorColors.warning,
        _ => HunorColors.red,
      };

  IconData get icon => switch (alert.type) {
        'exercise' => Icons.fitness_center,
        'standby' => Icons.hourglass_top_rounded,
        _ => Icons.warning_amber_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final response = s.alertResponses[alert.id];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(context, s, response),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 64,
                decoration: BoxDecoration(
                  color: accent.withAlpha(35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: muted ? HunorColors.muted : accent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.typeLabel,
                      style: TextStyle(
                        color: muted ? HunorColors.muted : accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: HunorColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (response != null)
                Icon(
                  response == 'available' ? Icons.check_circle : Icons.cancel,
                  color: response == 'available' ? HunorColors.success : HunorColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, AppStore s, String? response) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: HunorColors.surface,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                alert.typeLabel,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                alert.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              Text(
                alert.message,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 20),
              if (response != null)
                Text(
                  response == 'available' ? 'Válaszod: ELÉRHETŐ' : 'Válaszod: NEM ELÉRHETŐ',
                  style: TextStyle(
                    color: response == 'available' ? HunorColors.success : HunorColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  Navigator.pop(context);
                  try {
                    await s.respondToAlert(alert.id, true);
                    messenger?.showSnackBar(
                      SnackBar(content: Text(s.lastResponseMessage)),
                    );
                  } on ApiException catch (e) {
                    messenger?.showSnackBar(
                      SnackBar(content: Text('Hiba: ${e.message}'), backgroundColor: HunorColors.red),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Elérhető vagyok'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  Navigator.pop(context);
                  try {
                    await s.respondToAlert(alert.id, false);
                    messenger?.showSnackBar(
                      SnackBar(content: Text(s.lastResponseMessage)),
                    );
                  } on ConflictException catch (e) {
                    messenger?.showSnackBar(
                      SnackBar(content: Text('Hiba: ${e.message}'), backgroundColor: HunorColors.red),
                    );
                  }
                },
                icon: const Icon(Icons.close),
                label: const Text('Nem vagyok elérhető'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateAlertDialog extends StatefulWidget {
  final AppStore store;

  const _CreateAlertDialog({required this.store});

  @override
  State<_CreateAlertDialog> createState() => _CreateAlertDialogState();
}

class _CreateAlertDialogState extends State<_CreateAlertDialog> {
  String _type = 'exercise';
  final _titleController = TextEditingController(text: 'HUNOR Próbariasztás - Rendszergyakorlat');
  final _messageController = TextEditingController(
    text: 'Központi próbariasztás a HUNOR állomány számára. Kérjük jelezd a bevethetőségedet az Elérhető vagy Nem elérhető gombbal!',
  );
  int _durationHours = 24;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HunorColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_alert_rounded, color: HunorColors.exercise, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Új Próbariasztás Kiküldése',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        Text(
                          'Központi riasztásküldés az állomány tagjainak',
                          style: TextStyle(fontSize: 12, color: HunorColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              const Text(
                'RIASZTÁS TÍPUSA',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: HunorColors.muted),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _TypeChip(
                      label: 'Gyakorlat',
                      subtitle: 'Próba',
                      icon: Icons.fitness_center,
                      color: HunorColors.exercise,
                      selected: _type == 'exercise',
                      onTap: () => setState(() {
                        _type = 'exercise';
                        if (_titleController.text.isEmpty || _titleController.text.contains('Riasztás') || _titleController.text.contains('Készenlét')) {
                          _titleController.text = 'HUNOR Próbariasztás - Rendszergyakorlat';
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeChip(
                      label: 'Készenlét',
                      subtitle: 'Standby',
                      icon: Icons.hourglass_top_rounded,
                      color: HunorColors.warning,
                      selected: _type == 'standby',
                      onTap: () => setState(() {
                        _type = 'standby';
                        _titleController.text = 'Készenlétbe helyezés - HUNOR Állomány';
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeChip(
                      label: 'Riasztás',
                      subtitle: 'Éles',
                      icon: Icons.warning_amber_rounded,
                      color: HunorColors.red,
                      selected: _type == 'alert',
                      onTap: () => setState(() {
                        _type = 'alert';
                        _titleController.text = 'ÉLES RIASZTÁS - Azonnali Bevonulás';
                      }),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Text(
                'RIASZTÁS MEGNEVEZÉSE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: HunorColors.muted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: HunorColors.surface2,
                  hintText: 'Pl. HUNOR Próbariasztás',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: HunorColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: HunorColors.border)),
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                'RIASZTÁSI SZÖVEGES ÜZENET',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: HunorColors.muted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: HunorColors.surface2,
                  hintText: 'Részletes információk az állomány számára...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: HunorColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: HunorColors.border)),
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                'ÉRVÉNYESSÉGI IDŐ (LEJÁRAT)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: HunorColors.muted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [2, 6, 12, 24, 48].map((h) {
                  final sel = _durationHours == h;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _durationHours = h),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel ? HunorColors.exercise : HunorColors.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sel ? HunorColors.exercise : HunorColors.border),
                          ),
                          child: Text(
                            '$h óra',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w900 : FontWeight.w600,
                              color: sel ? Colors.white : HunorColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              FilledButton.icon(
                onPressed: _submitting ? null : _sendAlert,
                style: FilledButton.styleFrom(
                  backgroundColor: _type == 'alert' ? HunorColors.red : HunorColors.exercise,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _submitting ? 'Kiküldés folyamatban...' : 'Riasztás azonnali kiküldése',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HunorColors.muted,
                  side: const BorderSide(color: HunorColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Mégse'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendAlert() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final expiresAt = DateTime.now().add(Duration(hours: _durationHours));
      await widget.store.createAlert(title, message, _type, expiresAt);
      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Próbariasztás sikeresen kiküldve: "$title"')),
              ],
            ),
            backgroundColor: HunorColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Hiba a riasztás kiküldésekor: $e'),
            backgroundColor: HunorColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : HunorColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : HunorColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? Colors.white : HunorColors.text,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: selected ? color : HunorColors.muted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
