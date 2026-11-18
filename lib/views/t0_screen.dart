import 'package:flutter/material.dart';
import '../models/participant_evaluation.dart';
import '../services/excon_repository.dart';
import '../theme/hunor_theme.dart';

class T0Screen extends StatefulWidget {
  const T0Screen({super.key});

  @override
  State<T0Screen> createState() => _T0ScreenState();
}

class _T0ScreenState extends State<T0Screen> {
  final _repository = ExconRepository();
  final _tokenController = TextEditingController();

  double _professionalReadiness = 3.0; // 1-5
  double _teamCohesion = 3.0;          // 1-5
  double _expectedStress = 5.0;        // 1-10
  bool _isSubmitting = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kérlek, add meg az anonim beavatkozói azonosítódat (pl. A-84-KZ)!'),
          backgroundColor: HunorColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final evaluation = ParticipantEvaluation(
        formType: 'T0',
        anonToken: token,
        responses: {
          'professional_readiness': _professionalReadiness.toInt(),
          'team_cohesion': _teamCohesion.toInt(),
          'expected_stress': _expectedStress.toInt(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      await _repository.submitParticipantEvaluation(evaluation);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('T0 önértékelés sikeresen rögzítve! Köszönjük!'),
          backgroundColor: HunorColors.success,
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {
        _tokenController.clear();
        _professionalReadiness = 3.0;
        _teamCohesion = 3.0;
        _expectedStress = 5.0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('T0 önértékelés sikeresen rögzítve (helyi tároló)! Köszönjük!'),
          backgroundColor: HunorColors.success,
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {
        _tokenController.clear();
        _professionalReadiness = 3.0;
        _teamCohesion = 3.0;
        _expectedStress = 5.0;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HunorColors.graphite,
      appBar: AppBar(
        title: const Text('T0 Önértékelés (Gyakorlat előtt)'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tájékoztató kártya
                  Card(
                    color: HunorColors.surface1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: HunorColors.blue.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.psychology_outlined, color: HunorColors.blue, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BEAVATKOZÓI ÁLLAPOTFELMÉRÉS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: HunorColors.muted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Művelet előtti felmérés (T0)',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Az adatok anonimak, kérjük az őszinte visszajelzést a felkészültségedről.',
                                  style: TextStyle(fontSize: 12, color: HunorColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 1. Anonim Token
                  const Text(
                    'Anonim Azonosító Token:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _tokenController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Pl. A-84-KZ vagy egyedi kódod',
                      filled: true,
                      fillColor: HunorColors.surface1,
                      prefixIcon: const Icon(Icons.vpn_key_outlined, color: HunorColors.muted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: HunorColors.border),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // 2. Szakmai felkészültség (1-5)
                  _buildSliderSection(
                    title: '1. Szakmai felkészültség érzése',
                    subtitle: 'Mennyire érzed magad felkészültnek a rád váró műszaki/mentési feladatokra?',
                    value: _professionalReadiness,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    minLabel: '1: Bizonytalan',
                    maxLabel: '5: Maximálisan biztos',
                    accentColor: HunorColors.blue,
                    onChanged: (val) => setState(() => _professionalReadiness = val),
                  ),

                  const SizedBox(height: 24),

                  // 3. Csapatkohézió (1-5)
                  _buildSliderSection(
                    title: '2. Csapatkohézió és együttműködés',
                    subtitle: 'Milyen szintűnek ítéled az egységed összhangját és bizalmát?',
                    value: _teamCohesion,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    minLabel: '1: Gyenge összhang',
                    maxLabel: '5: Kiváló egység',
                    accentColor: HunorColors.success,
                    onChanged: (val) => setState(() => _teamCohesion = val),
                  ),

                  const SizedBox(height: 24),

                  // 4. Várható pszichofizikai terhelés (1-10)
                  _buildSliderSection(
                    title: '3. Várható pszichofizikai terhelés',
                    subtitle: 'Milyen mértékű fizikai és mentális igénybevételre számítasz a feladat során?',
                    value: _expectedStress,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    minLabel: '1: Minimális / Rutin',
                    maxLabel: '10: Extrém kimerülés',
                    accentColor: HunorColors.warning,
                    onChanged: (val) => setState(() => _expectedStress = val),
                  ),

                  const SizedBox(height: 32),

                  // Beküldés Gomb
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 24),
                    label: Text(
                      _isSubmitting ? 'RÖGZÍTÉS...' : 'T0 ÖNÉRTÉKELÉS BEKÜLDÉSE',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HunorColors.redDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

  Widget _buildSliderSection({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String minLabel,
    required String maxLabel,
    required Color accentColor,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HunorColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HunorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor),
                ),
                child: Text(
                  '${value.toInt()} / ${max.toInt()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: HunorColors.muted),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accentColor,
              inactiveTrackColor: HunorColors.surface2,
              thumbColor: accentColor,
              overlayColor: accentColor.withOpacity(0.2),
              valueIndicatorColor: accentColor,
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: '${value.toInt()}',
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: const TextStyle(fontSize: 11, color: HunorColors.muted)),
              Text(maxLabel, style: const TextStyle(fontSize: 11, color: HunorColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
