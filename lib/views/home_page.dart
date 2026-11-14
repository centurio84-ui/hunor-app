import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';
import 'excon_dashboard_screen.dart';
import 'organization_switcher_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final now = DateTime.now();
    final next = s.events.where((e) => e.date.isAfter(now)).firstOrNull;
    final activeAlerts = s.alerts.where((a) => a.isActive).length;
    final u = s.currentUser;
    final org = s.currentOrganization;
    final membership = s.currentMembership;
    final coin = s.coinBalance;

    return RefreshIndicator(
      onRefresh: s.loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Fejléc üdvözlés
          Text(
            'Üdv, ${u?.name ?? 'Mentőtag'}!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text('Központi Műveleti Áttekintés', style: TextStyle(color: HunorColors.muted)),
          const SizedBox(height: 16),

          // Aktív Szervezet kártya
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [HunorColors.navyCard, Color(0xFF162544)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: HunorColors.gold.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrganizationSwitcherView(
                        api: s.api,
                        onOrganizationChanged: () => s.loadData(),
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: HunorColors.gold.withOpacity(0.3)),
                        ),
                        child: Image.asset(
                          'assets/images/hunor_badge.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shield_outlined, size: 30, color: HunorColors.gold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    org?.name ?? 'HUNOR Nehéz Kutató-Mentő',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              membership != null
                                  ? 'Tagság: ${membership.membershipStatus.label} • ${membership.positions.join(", ")}'
                                  : 'Központi Műveleti Rendszer',
                              style: const TextStyle(color: HunorColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.swap_horiz_rounded, color: HunorColors.gold),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Rescue Coin (RC) Egyenleg kártya
          if (s.showRescueCoins && coin != null)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: HunorColors.warning.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.monetization_on_outlined, color: HunorColors.warning, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RESCUE COIN EGYENLEG',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                              color: HunorColors.warning,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${coin.balance} ${coin.unit}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Verzió: ${coin.ledgerVersion}',
                      style: const TextStyle(color: HunorColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Számlálók: Riasztások és Események
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.warning_amber_rounded,
                  value: '$activeAlerts',
                  label: 'Aktív riasztás',
                  accent: activeAlerts > 0 ? HunorColors.red : HunorColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.calendar_month_outlined,
                  value: '${s.events.length}',
                  label: 'Szervezeti esemény',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // EXCON szakmai értékelések és objektív mérések gomb
          Card(
            color: HunorColors.surface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: HunorColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExconDashboardScreen()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.insert_chart_outlined_rounded, color: HunorColors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'EXCON szakmai értékelések és objektív mérések ->',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: HunorColors.muted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Következő esemény
          Text('Következő esemény ebben a szervezetben', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (next == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.event_available_outlined, color: HunorColors.success),
                    SizedBox(width: 12),
                    Text('Nincs közelgő esemény rögzítve.', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 64,
                      decoration: BoxDecoration(
                        color: HunorColors.exercise.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${next.date.day}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: HunorColors.exercise),
                          ),
                          Text(
                            '${next.date.month}. hó',
                            style: const TextStyle(fontSize: 11, color: HunorColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(next.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(_date(next.date), style: const TextStyle(color: HunorColors.muted)),
                          if (next.location.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(next.location, style: const TextStyle(color: HunorColors.muted, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color accent;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.accent = HunorColors.text,
  });

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HunorColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: accent),
                    ),
                    Text(
                      label,
                      style: const TextStyle(color: HunorColors.muted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
