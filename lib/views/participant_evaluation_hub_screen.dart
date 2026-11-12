import 'package:flutter/material.dart';
import '../theme/hunor_theme.dart';
import 't0_screen.dart';
import 't1_screen.dart';

class ParticipantEvaluationHubScreen extends StatelessWidget {
  const ParticipantEvaluationHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HunorColors.graphite,
      appBar: AppBar(
        title: const Text('Beavatkozói Önértékelés'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'HUNOR GYAKORLATI ÉRTÉKELÉS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: HunorColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kérjük, válaszd ki a feladat fázisának megfelelő kérdőívet:',
                    style: TextStyle(fontSize: 15, color: HunorColors.text),
                  ),
                  const SizedBox(height: 20),

                  // T0 Kártya
                  _buildFormCard(
                    context,
                    title: 'T0 Felmérés (Művelet előtt)',
                    subtitle: 'Szakmai felkészültség, csapatkohézió és várt terhelés becslése.',
                    icon: Icons.psychology_outlined,
                    accentColor: HunorColors.blue,
                    routePath: '/t0',
                    targetWidget: const T0Screen(),
                  ),

                  const SizedBox(height: 16),

                  // T1 Kártya
                  _buildFormCard(
                    context,
                    title: 'T1 Felmérés (Művelet után)',
                    subtitle: 'Megélt terhelés, valóság vs. várakozás és a szituáció életszerűsége.',
                    icon: Icons.fact_check_outlined,
                    accentColor: HunorColors.success,
                    routePath: '/t1',
                    targetWidget: const T1Screen(),
                  ),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HunorColors.surface1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HunorColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline, color: HunorColors.muted, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'A kitöltés teljes mértékben anonim. Az azonosító token alapján a rendszer kizárólag a T0 és T1 válaszok párba állítására szolgál.',
                            style: TextStyle(fontSize: 12, color: HunorColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String routePath,
    required Widget targetWidget,
  }) {
    return Card(
      color: HunorColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: HunorColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => targetWidget),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: HunorColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: HunorColors.muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
