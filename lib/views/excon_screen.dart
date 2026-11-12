import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/excon_evaluation.dart';
import '../services/app_store.dart';
import '../services/excon_repository.dart';
import '../theme/hunor_theme.dart';

class ExconScreen extends StatefulWidget {
  final String? evaluatorName;

  const ExconScreen({
    super.key,
    this.evaluatorName,
  });

  @override
  State<ExconScreen> createState() => _ExconScreenState();
}

class _ExconScreenState extends State<ExconScreen> {
  final _repository = ExconRepository();
  final _commentController = TextEditingController();

  final List<Map<String, String>> _checkpointOptions = const [
    {'code': 'OP-K9-01', 'title': 'Keresőkutya bevetési fegyelem és irányítás'},
    {'code': 'OP-K9-02', 'title': 'Dekontaminációs és állategészségügyi eljárás'},
    {'code': 'III/C-1', 'title': 'Kárhelyszíni felderítés és veszélyzóna kijelölése'},
    {'code': 'III/C-2', 'title': 'Műszaki mentési fedezet és stabilizálás'},
    {'code': 'MED-01', 'title': 'Egészségügyi ellátó pont és triázs eljárás'},
    {'code': 'LOG-01', 'title': 'Logisztikai bázis és BoO biztonsági eljárás'},
  ];

  late String _selectedCheckpointCode;
  int? _selectedScore;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCheckpointCode = _checkpointOptions.first['code']!;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(String evaluator) async {
    if (_selectedScore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kérlek, válassz egy pontszámot (0, 1 vagy 2)!'),
          backgroundColor: HunorColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final evaluation = ExconEvaluation(
        evaluatorName: evaluator.isNotEmpty ? evaluator : 'EXCON Ellenőr',
        checkpointCode: _selectedCheckpointCode,
        score: _selectedScore!,
        comment: _commentController.text,
      );

      await _repository.submitEvaluation(evaluation);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Értékelés sikeresen rögzítve ($_selectedCheckpointCode)!'),
          backgroundColor: HunorColors.success,
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _selectedScore = null;
        _commentController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mentési hiba: $e'),
          backgroundColor: HunorColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore?>();
    final activeUser = store?.currentUser?.name ?? widget.evaluatorName ?? 'EXCON Értékelő';

    return Scaffold(
      backgroundColor: HunorColors.graphite,
      appBar: AppBar(
        title: const Text('EXCON Értékelés'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Értékelő adatai kártya
              Card(
                color: HunorColors.surface1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: HunorColors.redDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_ind_outlined, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ÉRTÉKELŐ BIZTOS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: HunorColors.muted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              activeUser,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 1. INSARAG Kód Dropdown
              const Text(
                'INSARAG Ellenőrzőpont (Checkpoint):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedCheckpointCode,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: HunorColors.surface1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HunorColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                dropdownColor: HunorColors.surface2,
                items: _checkpointOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['code'],
                    child: Text(
                      '${opt['code']} - ${opt['title']}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCheckpointCode = val);
                  }
                },
              ),

              const SizedBox(height: 22),

              // 2. Három nagy pontozó gomb kesztyűhöz (0, 1, 2)
              const Text(
                'Pontszám rögzítése:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),

              _buildScoreButton(
                score: 0,
                label: '0 PONT  ·  NEM MEGFELELŐ',
                activeColor: HunorColors.red,
                inactiveBg: HunorColors.red.withOpacity(0.12),
                icon: Icons.cancel_outlined,
              ),
              const SizedBox(height: 12),

              _buildScoreButton(
                score: 1,
                label: '1 PONT  ·  RÉSZBEN MEGFELELŐ',
                activeColor: HunorColors.warning,
                inactiveBg: HunorColors.warning.withOpacity(0.12),
                icon: Icons.change_circle_outlined,
              ),
              const SizedBox(height: 12),

              _buildScoreButton(
                score: 2,
                label: '2 PONT  ·  MEGFELELŐ / KIVÁLÓ',
                activeColor: HunorColors.success,
                inactiveBg: HunorColors.success.withOpacity(0.12),
                icon: Icons.check_circle_outline,
              ),

              const SizedBox(height: 22),

              // 3. Opcionális megjegyzés
              const Text(
                'Megjegyzés / Kárhelyszíni észrevétel (opcionális):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Pl. Hiányzó védőszemüveg belépéskor, késedelmes jelentéstétel...',
                  filled: true,
                  fillColor: HunorColors.surface1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HunorColors.border),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 4. Beküldés gomb
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : () => _submit(activeUser),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 24),
                label: Text(
                  _isSubmitting ? 'RÖGZÍTÉS FOLYAMATBAN...' : 'BEKÜLDÉS',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
  );
}

  Widget _buildScoreButton({
    required int score,
    required String label,
    required Color activeColor,
    required Color inactiveBg,
    required IconData icon,
  }) {
    final isSelected = _selectedScore == score;

    return InkWell(
      onTap: () => setState(() => _selectedScore = score),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: activeColor,
            width: isSelected ? 3.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : activeColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : activeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
