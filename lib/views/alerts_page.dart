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

    return RefreshIndicator(
      onRefresh: s.loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
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
