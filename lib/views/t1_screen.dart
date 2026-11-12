import 'package:flutter/material.dart';
import '../models/participant_evaluation.dart';
import '../services/excon_repository.dart';
import '../theme/hunor_theme.dart';

class T1Screen extends StatefulWidget {
  const T1Screen({super.key});

  @override
  State<T1Screen> createState() => _T1ScreenState();
}

class _T1ScreenState extends State<T1Screen> {
  final _repository = ExconRepository();
  final _tokenController = TextEditingController();

  double _experiencedStress = 5.0;        // 1-10
  double _competenceCorrection = 3.0;     // 1-5 (Mennyivel volt nehezebb a vártnál)
  double _realismScore = 4.0;             // 1-5 (Gyakorlat realisztikussága)
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
        formType: 'T1',
        anonToken: token,
        responses: {
          'experienced_stress': _experiencedStress.toInt(),
          'competence_correction': _competenceCorrection.toInt(),
          'realism_score': _realismScore.toInt(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      await _repository.submitParticipantEvaluation(evaluation);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('T1 utólagos önértékelés sikeresen rögzítve! Köszönjük a munkádat!'),
          backgroundColor: HunorColors.success,
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {
        _tokenController.clear();
        _experiencedStress = 5.0;
        _competenceCorrection = 3.0;
        _realismScore = 4.0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hiba a beküldéskor: $e'),
          backgroundColor: HunorColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HunorColors.graphite,
      appBar: AppBar(
        title: const Text('T1 Önértékelés (Gyakorlat után)'),
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
                              color: HunorColors.success.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.done_all_rounded, color: HunorColors.success, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BEAVATKOZÁS UTÁNI ÉRTÉKELÉS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: HunorColors.muted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Utólagos visszajelzés (T1)',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Kérjük, értékeld a megélt terhelést és tapasztalatokat a feladat befejezése után.',
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
                    'Anonim Azonosító Token (Ugyanaz, mint a T0-nál):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _tokenController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Pl. A-84-KZ',
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

                  // 2. Megélt fizikai / kognitív terhelés (1-10)
                  _buildSliderSection(
                    title: '1. Megélt fizikai és kognitív terhelés',
                    subtitle: 'Milyen mértékű valós megterhelést tapasztaltál a feladat végrehajtása során?',
                    value: _experiencedStress,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    minLabel: '1: Könnyű menet',
                    maxLabel: '10: Végkimerülés',
                    accentColor: HunorColors.red,
                    onChanged: (val) => setState(() => _experiencedStress = val),
                  ),

                  const SizedBox(height: 24),

                  // 3. Kompetencia-korrekció (1-5)
                  _buildSliderSection(
                    title: '2. Kompetencia-korrekció (Várakozás vs. Valóság)',
                    subtitle: 'Mennyivel volt nehezebb vagy összetettebb a helyszíni feladat a vártnál?',
                    value: _competenceCorrection,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    minLabel: '1: Sokkal könnyebb volt',
                    maxLabel: '5: Sokkal nehezebb volt',
                    accentColor: HunorColors.warning,
                    onChanged: (val) => setState(() => _competenceCorrection = val),
                  ),

                  const SizedBox(height: 24),

                  // 4. Gyakorlat realisztikussága (1-5)
                  _buildSliderSection(
                    title: '3. Gyakorlati szituáció életszerűsége (Realisztikusság)',
                    subtitle: 'Mennyire tükrözte a romterület és a helyzet a valós INSARAG bevetési körülményeket?',
                    value: _realismScore,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    minLabel: '1: Művi / Nem életszerű',
                    maxLabel: '5: Rendkívül realisztikus',
                    accentColor: HunorColors.blue,
                    onChanged: (val) => setState(() => _realismScore = val),
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
                      _isSubmitting ? 'RÖGZÍTÉS...' : 'T1 ÉRTÉKELÉS BEKÜLDÉSE',
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
