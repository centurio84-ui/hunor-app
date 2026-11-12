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
    // I. Mobilizáció és Érkezés
    {'code': '1.1', 'title': 'Riasztási protokoll és csapattagok beérkezése', 'category': 'I. Mobilizáció és Érkezés'},
    {'code': '1.2', 'title': 'DGR és veszélyes áru vámlista, szállítási dokumentáció', 'category': 'I. Mobilizáció és Érkezés'},
    {'code': '1.3', 'title': 'Egészségügyi és oltási alkalmassági ellenőrzés', 'category': 'I. Mobilizáció és Érkezés'},
    {'code': '1.4', 'title': 'Személyi és technikai felszerelés ellenőrzése, mérlegelése', 'category': 'I. Mobilizáció és Érkezés'},
    {'code': '1.5', 'title': 'RDC / Érkezési központ regisztráció és eljárás', 'category': 'I. Mobilizáció és Érkezés'},
    {'code': '1.6', 'title': 'Műveleti bázis (BoO) helyszínválasztás és bázisépítés', 'category': 'I. Mobilizáció és Érkezés'},

    // II. Kárhelyszíni Koordináció
    {'code': '2.1', 'title': 'OSOCC eligazítás és szektorbeosztás átvétele', 'category': 'II. Kárhelyszíni Koordináció'},
    {'code': '2.2', 'title': 'ICMS digitális kárhelykezelő rendszer használata', 'category': 'II. Kárhelyszíni Koordináció'},
    {'code': '2.3', 'title': 'ASR1 széles körű és ASR2 szektor felderítés', 'category': 'II. Kárhelyszíni Koordináció'},
    {'code': '2.4', 'title': 'Helyi hatóságokkal (LEMA) történő kapcsolattartás', 'category': 'II. Kárhelyszíni Koordináció'},
    {'code': '2.5', 'title': 'Kárhelyszíni INSARAG jelölési rendszer alkalmazása', 'category': 'II. Kárhelyszíni Koordináció'},
    {'code': '2.6', 'title': 'Nemzetközi és társegységekkel való együttműködés', 'category': 'II. Kárhelyszíni Koordináció'},

    // III. Műveleti Tervezés
    {'code': '3.1', 'title': '12 órás Műveleti Terv (IAP) kidolgozása', 'category': 'III. Műveleti Tervezés'},
    {'code': '3.2', 'title': 'Alegységek feladatszabása és műveleti célok kitűzése', 'category': 'III. Műveleti Tervezés'},
    {'code': '3.3', 'title': 'Logisztikai ellátási lánc és üzemanyag-utánpótlás', 'category': 'III. Műveleti Tervezés'},
    {'code': '3.4', 'title': 'Váltási rend, pihentetés és rotációs protokoll', 'category': 'III. Műveleti Tervezés'},
    {'code': '3.5', 'title': 'Tájékoztatási rend és UCC jelentéstétel az OSOCC felé', 'category': 'III. Műveleti Tervezés'},
    {'code': '3.6', 'title': 'Műveleti kommunikációs csatornák és rádióhálózat', 'category': 'III. Műveleti Tervezés'},

    // IV. Biztonság és Veszélyhelyzet
    {'code': '4.1', 'title': 'Kárhelyszíni Biztonsági Tiszt (Safety Officer) jelenléte', 'category': 'IV. Biztonság és Veszélyhelyzet'},
    {'code': '4.2', 'title': 'Folyamatos HAZMAT és gázkoncentráció-monitoring', 'category': 'IV. Biztonság és Veszélyhelyzet'},
    {'code': '4.3', 'title': 'Vészkiürítési jelzés és evakuációs terv', 'category': 'IV. Biztonság és Veszélyhelyzet'},
    {'code': '4.4', 'title': 'MEDEVAC és sérültmentési vészhelyzeti protokoll', 'category': 'IV. Biztonság és Veszélyhelyzet'},
    {'code': '4.5', 'title': 'Statikai stabilitás és másodlagos omlásvédelem', 'category': 'IV. Biztonság és Veszélyhelyzet'},
    {'code': '4.6', 'title': 'Pszichoszociális támogatás és terheléskezelés', 'category': 'IV. Biztonság és Veszélyhelyzet'},

    // V. Demobilizáció
    {'code': '5.1', 'title': 'ASR 5 műveleti lezárási eljárás', 'category': 'V. Demobilizáció'},
    {'code': '5.2', 'title': 'Kárhelyszínek átadása a helyi hatóságoknak (LEMA)', 'category': 'V. Demobilizáció'},
    {'code': '5.3', 'title': 'BoO bázis bontása és terület-rehabilitáció', 'category': 'V. Demobilizáció'},
    {'code': '5.4', 'title': 'Eszközök és felszerelések dekontaminációja', 'category': 'V. Demobilizáció'},
    {'code': '5.5', 'title': 'OSOCC zárójelentés és kilépési regisztráció', 'category': 'V. Demobilizáció'},
    {'code': '5.6', 'title': 'Hazaérkezési és logisztikai elszámolási terv', 'category': 'V. Demobilizáció'},

    // III/A. K9 Keresőkutyás Kutatás
    {'code': 'OP-K9-01', 'title': 'Kutyák rotációja, pihentetése és dehidratáció megelőzése', 'category': 'III/A. K9 Kutatás'},
    {'code': 'OP-K9-02', 'title': 'Szélirány és területfelosztás helyes meghatározása a kárhelyen', 'category': 'III/A. K9 Kutatás'},
    {'code': 'OP-K9-03', 'title': 'Jelzések (ugatás) megerősítése második kutyával vagy műszaki keresővel', 'category': 'III/A. K9 Kutatás'},
    {'code': 'OP-K9-04', 'title': 'Kutyavezető és kárhelyszíni biztonsági tiszt (Safety Officer) kommunikációja', 'category': 'III/A. K9 Kutatás'},
    {'code': 'OP-K9-05', 'title': 'Állatorvosi (K9 First Aid) protokoll és felszerelés készenléte', 'category': 'III/A. K9 Kutatás'},

    // III/B. Vágás (Cutting)
    {'code': 'OP-CUT-01', 'title': 'Megfelelő eszközválasztás (pl. flex vs. plazmavágó) anyagismeret alapján', 'category': 'III/B. Vágás'},
    {'code': 'OP-CUT-02', 'title': 'Szikravédelem, tűzbiztonság és poroltó/víz jelenléte a vágásnál', 'category': 'III/B. Vágás'},
    {'code': 'OP-CUT-03', 'title': 'Vágási pontok helyes meghatározása (feszültségmentesítés és teheráthelyezés elkerülése)', 'category': 'III/B. Vágás'},
    {'code': 'OP-CUT-04', 'title': 'Eszközök hűtése, karbantartása és üzemanyag/áramellátás logisztikája', 'category': 'III/B. Vágás'},
    {'code': 'OP-CUT-05', 'title': 'Személyi védőfelszerelés (szem-, fül-, arcvédő, kesztyű) szigorú betartása', 'category': 'III/B. Vágás'},

    // III/C. Törés (Breaching)
    {'code': 'OP-BRK-01', 'title': 'Furatképzés és törési technika pontossága (vasalás és vezetékek elkerülése)', 'category': 'III/C. Törés'},
    {'code': 'OP-BRK-02', 'title': '"Clean breach" (tiszta áttörés) alkalmazása koszos/omló áttörés helyett', 'category': 'III/C. Törés'},
    {'code': 'OP-BRK-03', 'title': 'Porképződés gátlása (vízpermet) és légzésvédelem', 'category': 'III/C. Törés'},
    {'code': 'OP-BRK-04', 'title': 'Zaj- és vibrációkontroll a túlélők és a statikai stabilitás védelmében', 'category': 'III/C. Törés'},
    {'code': 'OP-BRK-05', 'title': 'Betondarabok és törmelék biztonságos eltávolítása, mozgatása és rögzítése', 'category': 'III/C. Törés'},

    // III/D. Alpin (Rope rescue)
    {'code': 'OP-ROP-01', 'title': 'Kikötési pontok (Anchor points) teherbírása, Y-kikötések és redundancia', 'category': 'III/D. Alpin'},
    {'code': 'OP-ROP-02', 'title': 'Csigarendszerek (pl. 3:1, 4:1) szakszerű és hatékony kiépítése', 'category': 'III/D. Alpin'},
    {'code': 'OP-ROP-03', 'title': 'Kötélvédelem (élvédők) szigorú és folyamatos használata', 'category': 'III/D. Alpin'},
    {'code': 'OP-ROP-04', 'title': 'Kettős kötélrendszer (teher- és személybiztosítás független szálakon)', 'category': 'III/D. Alpin'},
    {'code': 'OP-ROP-05', 'title': 'Tiszta parancsok és kommunikáció az eresztő/húzó és a peremőr között', 'category': 'III/D. Alpin'},

    // III/E. Shoring (Dúcolás)
    {'code': 'OP-SHR-01', 'title': 'Faanyag helyes kiválasztása, mérése és méretre vágása (tűréshatárok)', 'category': 'III/E. Dúcolás'},
    {'code': 'OP-SHR-02', 'title': 'Teherelosztók és ékek (wedges) helyes felhelyezése és rögzítése', 'category': 'III/E. Dúcolás'},
    {'code': 'OP-SHR-03', 'title': 'Dúcok (T-spot, Window, Door, Vertical) geometriai szögei és stabilitása', 'category': 'III/E. Dúcolás'},
    {'code': 'OP-SHR-04', 'title': 'Korai figyelmeztető rendszer (elmozdulás/repedés figyelése a dúcolás során)', 'category': 'III/E. Dúcolás'},
    {'code': 'OP-SHR-05', 'title': 'Biztonságos menekülési útvonal biztosítása a dúcolási munkaterületen', 'category': 'III/E. Dúcolás'},
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
