import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event_participation.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    if (s.events.isEmpty) {
      return RefreshIndicator(
        onRefresh: s.loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 80),
            Icon(Icons.event_available_outlined, size: 48, color: HunorColors.success),
            SizedBox(height: 12),
            Center(
              child: Text(
                'Nincs rögzített esemény ebben a szervezetben.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: s.loadData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: s.events.length,
        itemBuilder: (c, i) {
          final e = s.events[i];
          final r = s.eventResponses[e.id];
          final reg = s.eventRegistrations[e.id];
          final part = s.eventParticipations[e.id];
          final past = e.date.isBefore(DateTime.now());

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showEventDetailsSheet(c, s, e, reg, part, past),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 64,
                      decoration: BoxDecoration(
                        color: past ? HunorColors.surface2 : HunorColors.exercise.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${e.date.day}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: past ? HunorColors.muted : HunorColors.exercise,
                            ),
                          ),
                          Text('${e.date.month}. hó', style: const TextStyle(fontSize: 11, color: HunorColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text(_date(e.date), style: const TextStyle(color: HunorColors.muted)),
                          if (e.location.isNotEmpty)
                            Text(e.location, style: const TextStyle(color: HunorColors.muted)),
                          if (reg != null && reg.hasCapacityLimit) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Szabad helyek: ${reg.remainingSeats} / ${reg.maxCapacity}',
                              style: TextStyle(
                                fontSize: 12,
                                color: reg.isFull ? HunorColors.warning : HunorColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (r != null)
                      Icon(
                        r == 'going' ? Icons.check_circle : Icons.cancel,
                        color: r == 'going' ? HunorColors.success : HunorColors.muted,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEventDetailsSheet(
    BuildContext context,
    AppStore s,
    dynamic e,
    EventRegistrationInfo? reg,
    EventParticipation? part,
    bool past,
  ) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: HunorColors.surface,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_date(e.date), style: const TextStyle(color: HunorColors.exercise, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(e.title, style: Theme.of(c).textTheme.headlineSmall),
              if (e.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 16, color: HunorColors.muted),
                    const SizedBox(width: 6),
                    Text(e.location, style: const TextStyle(color: HunorColors.muted)),
                  ],
                ),
              ],
              if (e.details.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(e.details, style: const TextStyle(height: 1.4)),
              ],
              const SizedBox(height: 16),

              // CODEX-017 Részvételi és kapacitás információk kártyája
              if (reg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HunorColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 18, color: HunorColors.accent),
                          const SizedBox(width: 8),
                          Text(
                            reg.hasCapacityLimit
                                ? 'Létszámkeret: ${reg.currentGoingCount} / ${reg.maxCapacity} fő'
                                : 'Korlátlan létszámkeret',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (reg.registrationDeadline != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Jelentkezési határidő: ${_date(reg.registrationDeadline!)}',
                          style: const TextStyle(fontSize: 12, color: HunorColors.muted),
                        ),
                      ],
                      if (reg.cancellationDeadline != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Lemondási határidő: ${_date(reg.cancellationDeadline!)}',
                          style: const TextStyle(fontSize: 12, color: HunorColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (!past) ...[
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(c);
                    s.respondToEvent(e.id, true);
                  },
                  icon: Icon(part?.isGoing == true ? Icons.check_circle : Icons.check_circle_outline),
                  label: Text(part?.isGoing == true ? 'Részt veszek ✓' : 'Részt veszek'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(c);
                    s.respondToEvent(e.id, false);
                  },
                  icon: Icon(part?.isNotGoing == true ? Icons.cancel : Icons.cancel_outlined),
                  label: Text(part?.isNotGoing == true ? 'Nem veszek részt ✓' : 'Nem veszek részt'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
