import 'package:flutter/material.dart';

import '../../theme/hunor_theme.dart';
import 'planning_catalog_panel.dart';
import 'planning_models.dart';
import 'planning_repository.dart';

const _obstaclesTable = 'Akadályok Asztala';

class _ObstacleCategory {
  const _ObstacleCategory({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;
}

const List<_ObstacleCategory> _obstacleCategories = [
  _ObstacleCategory(
    key: 'breaching',
    label: '14.9 Vágás, törés és áttörés',
    color: Color(0xFFE11D48),
  ),
  _ObstacleCategory(
    key: 'lifting',
    label: '14.10 Emelés és mozgatás',
    color: Color(0xFFEA580C),
  ),
  _ObstacleCategory(
    key: 'shoring',
    label: '14.11 Dúcolás és stabilizálás',
    color: Color(0xFFD97706),
  ),
  _ObstacleCategory(
    key: 'rope',
    label: '14.12 Kötéltechnika',
    color: Color(0xFF2563EB),
  ),
  _ObstacleCategory(
    key: 'confined_search',
    label: '14.8 / 14.13 Szűk tér & Kutatás',
    color: Color(0xFF0891B2),
  ),
  _ObstacleCategory(
    key: 'medical_obs',
    label: '14.14 Speciális EÜ beavatkozás',
    color: Color(0xFF991B1B),
  ),
];

_ObstacleCategory _obstacleCategoryByKey(String? key) {
  for (final c in _obstacleCategories) {
    if (c.key == key) return c;
  }
  return _obstacleCategories.first;
}

class _ObstacleTemplate {
  const _ObstacleTemplate({
    required this.code,
    required this.title,
    required this.categoryKey,
    required this.technicalSpec,
    required this.notes,
  });

  final String code;
  final String title;
  final String categoryKey;
  final String technicalSpec;
  final String notes;
}

const List<_ObstacleTemplate> _obstacleTemplates = [
  // 14.9 Vágás, törés és áttörés
  _ObstacleTemplate(
    code: '14.9.1',
    title: 'Vasbeton áttörés fej felett (felfelé)',
    categoryKey: 'breaching',
    technicalSpec: '200 mm vasbeton (Light/Medium/Heavy)',
    notes: 'Függőlegesen felfelé üregbe történő vasbeton áttörés.',
  ),
  _ObstacleTemplate(
    code: '14.9.2',
    title: 'Vasbeton áttörés oldalirányban',
    categoryKey: 'breaching',
    technicalSpec: '200 mm vasbeton (Light/Medium/Heavy)',
    notes: 'Oldalsó fal áttörése üregbe történő bejutáshoz.',
  ),
  _ObstacleTemplate(
    code: '14.9.3',
    title: 'Vasbeton áttörés lefelé („dirty” technika)',
    categoryKey: 'breaching',
    technicalSpec: '200 mm vasbeton (Light/Medium/Heavy)',
    notes: 'Függőlegesen lefelé áttörés szennyezett (dirty) technikával.',
  ),
  _ObstacleTemplate(
    code: '14.9.4',
    title: 'Tiszta vágás / áttörés lefelé („clean” technika)',
    categoryKey: 'breaching',
    technicalSpec: '200 mm vasbeton (Medium/Heavy)',
    notes: 'Függőlegesen lefelé tiszta áttörés (sérült védelmével a törmeléktől).',
  ),
  _ObstacleTemplate(
    code: '14.9.5',
    title: 'Vasbeton oszlop vagy gerenda átvágása',
    categoryKey: 'breaching',
    technicalSpec: 'Medium: 300 mm (12 mm vas) · Heavy: 450 mm (18 mm vas)',
    notes: 'Forgatókönyvbe integrált vasbeton szerkezeti elem átvágása.',
  ),
  _ObstacleTemplate(
    code: '14.9.6',
    title: 'Tömör fagerenda átvágása',
    categoryKey: 'breaching',
    technicalSpec: 'Light: 200 mm · Medium/Heavy: 300 mm',
    notes: 'Forgatókönyvbe integrált tömör fa szerkezeti elem átvágása.',
  ),
  _ObstacleTemplate(
    code: '14.9.7',
    title: 'Acél / fémlemez átvágása',
    categoryKey: 'breaching',
    technicalSpec: 'Light: 3 mm · Medium: 10 mm · Heavy: 20 mm',
    notes: 'Forgatókönyvbe integrált fémlemez átvágása megfelelő PPE-vel.',
  ),
  _ObstacleTemplate(
    code: '14.9.8',
    title: 'Szerkezeti acélgerenda (I/H-tartó) átvágása',
    categoryKey: 'breaching',
    technicalSpec: 'Heavy: 260×102 mm (6,5/10 mm) · ferde >45° + vízszintes',
    notes: '2 db I/H-tartó vágás, min. 1 szűk térben és min. 1 meleg fémvágással.',
  ),

  // 14.10 Emelés és mozgatás
  _ObstacleTemplate(
    code: '14.10.1',
    title: 'Pneumatikus emelőpárnás emelés + cribbing',
    categoryKey: 'lifting',
    technicalSpec: 'Medium: 1,0 MT · Heavy: 2,5 MT',
    notes: 'Fokozatos alátámasztás és stabilizálás az emelés teljes ideje alatt.',
  ),
  _ObstacleTemplate(
    code: '14.10.2',
    title: 'Hidraulikus emelés és mozgatás + cribbing',
    categoryKey: 'lifting',
    technicalSpec: 'Light/Medium: 1,0 MT · Heavy: 2,5 MT',
    notes: 'Betongerenda/oszlop emelése fokozatos alátámasztással.',
  ),
  _ObstacleTemplate(
    code: '14.10.3',
    title: 'Csörlős húzás / mozgatás kötözéssel',
    categoryKey: 'lifting',
    technicalSpec: 'Light/Medium: 1,0 MT · Heavy: 2,5 MT',
    notes: 'Hevederes/láncos kötözés; előregyártott emelőfülek tilosak.',
  ),
  _ObstacleTemplate(
    code: '14.10.4',
    title: 'Daruzási művelet (5,0 tonnás teher)',
    categoryKey: 'lifting',
    technicalSpec: '5,0 MT · min. 2 daruzás',
    notes: 'Kötözés és darukezelő irányítása egyeztetett jelzésekkel.',
  ),

  // 14.11 Dúcolás és stabilizálás
  _ObstacleTemplate(
    code: '14.11.4',
    title: 'Aládúcolás és kiékelés (Cribbing & Wedging)',
    categoryKey: 'shoring',
    technicalSpec: 'Teheremelés / stabilizálás közben',
    notes: 'Folyamatos kiékelés és teherátadás biztosítása.',
  ),
  _ObstacleTemplate(
    code: '14.11.5',
    title: 'Ablak- / ajtónyílás megtámasztása',
    categoryKey: 'shoring',
    technicalSpec: 'Window / door stabilisation',
    notes: 'Nyílászáró keret szakszerű megtámasztása vágóállomásról.',
  ),
  _ObstacleTemplate(
    code: '14.11.6',
    title: 'Függőleges megtámasztás (Vertical shoring)',
    categoryKey: 'shoring',
    technicalSpec: 'Medium / Heavy kötelező',
    notes: 'Függőleges teherviselő dúcolat építése keresztmerevítéssel.',
  ),
  _ObstacleTemplate(
    code: '14.11.7',
    title: 'Oldalirányú / ferde megtámasztás (Raker / Diagonal)',
    categoryKey: 'shoring',
    technicalSpec: 'Medium / Heavy kötelező',
    notes: 'Dőlt fal vagy szerkezet oldalirányú megtámasztása (Raker shore).',
  ),
  _ObstacleTemplate(
    code: '14.11.8',
    title: 'Vízszintes megtámasztás (Horizontal shoring)',
    categoryKey: 'shoring',
    technicalSpec: 'Medium / Heavy kötelező',
    notes: 'Két fal közötti vízszintes feszítő dúcolat kiépítése.',
  ),

  // 14.12 Kötéltechnika
  _ObstacleTemplate(
    code: '14.12.2',
    title: 'Függőleges kötéltechnikai emelés / eresztés',
    categoryKey: 'rope',
    technicalSpec: 'Min. 10 m · szimulált „élő” sérült',
    notes: 'Kettős kötélbiztosítású függőleges kiemelés vagy leeresztés.',
  ),
  _ObstacleTemplate(
    code: '14.12.3',
    title: 'Ferde kötélpálya / traverz rendszer',
    categoryKey: 'rope',
    technicalSpec: 'Min. 10 m szintkülönbség (Medium/Heavy)',
    notes: 'Szimulált „élő” sérült átjuttatása magas pontról alacsonyra.',
  ),

  // 14.8 & 14.13 Szűk tér & Kutatás
  _ObstacleTemplate(
    code: '14.13.2',
    title: 'Szűk téri behatolás (légtérmérés + szellőztetés)',
    categoryKey: 'confined_search',
    technicalSpec: '14.13.1–14.13.7 · gázmérés + ventiláció',
    notes: 'Kockázatértékelés, ki-/beléptetés, folyamatos légfigyelés és szellőztetés.',
  ),
  _ObstacleTemplate(
    code: '14.8.3',
    title: 'Technikai kutatás (kamera + szeizmikus/akusztikus)',
    categoryKey: 'confined_search',
    technicalSpec: '14.8.3–14.8.4 · kötelező minden szinten',
    notes: 'Keresőkamera és akusztikus/szeizmikus eszköz összehangolt bevetése.',
  ),
  _ObstacleTemplate(
    code: '14.8.5',
    title: 'Keresőkutyás (K9) kutatás romok alatt',
    categoryKey: 'confined_search',
    technicalSpec: 'Min. 4 keresés (nappal / éjjel) · Heavy kötelező',
    notes: 'Előre egyeztetett sérült-elhelyezéssel, eltérő napszakokban.',
  ),

  // 14.14 Speciális EÜ beavatkozás
  _ObstacleTemplate(
    code: '14.14.5',
    title: 'Terepi amputáció szűk térben',
    categoryKey: 'medical_obs',
    technicalSpec: 'Medium / Heavy kötelező · felső vagy alsó végtag',
    notes: 'Fájdalomcsillapítással, szedálással/anesztéziával szimulálva szűk térben.',
  ),
  _ObstacleTemplate(
    code: '14.14.6',
    title: 'Crush-szindrómás sérült ellátása szűk térben',
    categoryKey: 'medical_obs',
    technicalSpec: 'Light / Medium / Heavy kötelező',
    notes: 'Kiszabadítás előtti és alatti crush-protokoll gyakorlati bemutatása.',
  ),
];

class _ObstacleEdit {
  const _ObstacleEdit({
    required this.title,
    required this.categoryKey,
    required this.insaragCode,
    required this.technicalSpec,
    required this.notes,
    this.delete = false,
  });

  final String title;
  final String categoryKey;
  final String insaragCode;
  final String technicalSpec;
  final String notes;
  final bool delete;
}

class PlanningObstaclesBoard extends StatefulWidget {
  const PlanningObstaclesBoard({
    super.key,
    required this.exerciseId,
    required this.repository,
    this.onSavingChanged,
  });

  final String exerciseId;
  final PlanningRepository repository;
  final ValueChanged<bool>? onSavingChanged;

  @override
  State<PlanningObstaclesBoard> createState() => _PlanningObstaclesBoardState();
}

class _PlanningObstaclesBoardState extends State<PlanningObstaclesBoard> {
  ExerciseDetails? _details;
  bool _loadFailed = false;
  bool _saving = false;
  String? _saveError;
  String? _selectedCategoryKey;
  String _templateQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (_loadFailed) setState(() => _loadFailed = false);
    try {
      final details =
          await widget.repository.fetchExerciseDetails(widget.exerciseId);
      if (mounted) setState(() => _details = details);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _save(
    Future<ExerciseDetails> Function(ExerciseDetails) change,
    String error,
  ) async {
    final details = _details;
    if (!mounted || details == null || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    widget.onSavingChanged?.call(true);
    try {
      final updated = await change(details);
      if (mounted) setState(() => _details = updated);
    } catch (_) {
      if (mounted) setState(() => _saveError = error);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onSavingChanged?.call(false);
      }
    }
  }

  bool _isObstacleBubble(ExerciseBubble b) => b.specs['is_obstacle'] == true;

  String _insaragCode(ExerciseBubble b) =>
      (b.specs['insarag_code'] ?? '').toString().trim();

  String _technicalSpec(ExerciseBubble b) =>
      (b.specs['technical_spec'] ?? '').toString().trim();

  String _obstacleNotes(ExerciseBubble b) =>
      (b.specs['obstacle_notes'] ?? '').toString().trim();

  Future<void> _addFromTemplate(
    _ObstacleTemplate template, {
    String? sectorId,
    bool openDialogFirst = false,
  }) async {
    if (openDialogFirst) {
      await _editObstacle(template: template, initialSectorId: sectorId);
      return;
    }
    await _save(
      (details) async {
        final added = await widget.repository.addBubble(
          exerciseId: widget.exerciseId,
          sectorId: sectorId,
          title: template.title,
          discipline: BubbleDiscipline.custom,
          estimatedHours: null,
          specs: {
            'is_obstacle': true,
            'obstacle_category': template.categoryKey,
            'insarag_code': template.code,
            'technical_spec': template.technicalSpec,
            'obstacle_notes': template.notes,
          },
        );
        return (
          sectors: details.sectors,
          bubbles: [...details.bubbles, added],
        );
      },
      'Az akadály buborék felvétele nem sikerült.',
    );
  }

  Future<void> _editObstacle({
    ExerciseBubble? bubble,
    _ObstacleTemplate? template,
    String? initialSectorId,
  }) async {
    final edit = await showDialog<_ObstacleEdit>(
      context: context,
      builder: (_) => _ObstacleDialog(bubble: bubble, template: template),
    );
    if (!mounted || edit == null) return;

    await _save(
      (details) async {
        if (edit.delete && bubble != null) {
          await widget.repository.deleteBubble(
            exerciseId: widget.exerciseId,
            bubbleId: bubble.id,
          );
          return (
            sectors: details.sectors,
            bubbles:
                details.bubbles.where((item) => item.id != bubble.id).toList(),
          );
        }

        final specs = <String, dynamic>{
          if (bubble != null) ...bubble.specs,
          'is_obstacle': true,
          'obstacle_category': edit.categoryKey,
          'insarag_code': edit.insaragCode,
          'technical_spec': edit.technicalSpec,
          'obstacle_notes': edit.notes,
        };

        if (bubble == null) {
          final added = await widget.repository.addBubble(
            exerciseId: widget.exerciseId,
            sectorId: initialSectorId,
            title: edit.title,
            discipline: BubbleDiscipline.custom,
            estimatedHours: null,
            specs: specs,
          );
          return (
            sectors: details.sectors,
            bubbles: [...details.bubbles, added],
          );
        }

        final updated = await widget.repository.updateBubbleDetails(
          bubble: bubble,
          estimatedHours: bubble.estimatedHours,
          title: edit.title,
          specs: specs,
        );
        return _replaceBubble(details, updated);
      },
      edit.delete
          ? 'Az akadály törlése nem sikerült.'
          : 'Az akadály mentése nem sikerült.',
    );
  }

  Future<void> _deleteObstacle(ExerciseBubble bubble) => _save(
        (details) async {
          await widget.repository.deleteBubble(
            exerciseId: widget.exerciseId,
            bubbleId: bubble.id,
          );
          return (
            sectors: details.sectors,
            bubbles:
                details.bubbles.where((item) => item.id != bubble.id).toList(),
          );
        },
        'Az akadály törlése nem sikerült.',
      );

  Future<void> _duplicateObstacle(ExerciseBubble bubble) => _save(
        (details) async {
          final copy = await widget.repository.addBubble(
            exerciseId: widget.exerciseId,
            sectorId: bubble.sectorId,
            title: bubble.title,
            discipline: BubbleDiscipline.custom,
            estimatedHours: null,
            specs: {
              ...bubble.specs,
              'is_obstacle': true,
            },
          );
          return (
            sectors: details.sectors,
            bubbles: [...details.bubbles, copy],
          );
        },
        'Az akadály duplikálása nem sikerült.',
      );

  Future<void> _moveObstacle(ExerciseBubble bubble, String? sectorId) async {
    if (bubble.exerciseId != widget.exerciseId || bubble.sectorId == sectorId) {
      return;
    }
    await _save(
      (details) async => _replaceBubble(
        details,
        await widget.repository.moveBubble(bubble, sectorId),
      ),
      'Az akadály áthelyezése nem sikerült.',
    );
  }

  ExerciseDetails _replaceBubble(
    ExerciseDetails details,
    ExerciseBubble updated,
  ) =>
      (
        sectors: details.sectors,
        bubbles: [
          for (final b in details.bubbles)
            if (b.id == updated.id) updated else b,
        ],
      );

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final leftPanel =
        _buildLeftObstaclesPanel(enabled: details != null && !_saving);

    final Widget zones;
    if (_loadFailed) {
      zones = Column(
        children: [
          const Text('Az akadály-tábla betöltése nem sikerült.'),
          TextButton(
            onPressed: _loadDetails,
            child: const Text('Újrapróbálás'),
          ),
        ],
      );
    } else if (details == null) {
      zones = const Center(child: CircularProgressIndicator());
    } else {
      zones = _buildZones(context, details);
    }

    return Column(
      children: [
        if (_saving) const LinearProgressIndicator(),
        if (_saveError case final error?)
          ListTile(
            dense: true,
            leading: const Icon(Icons.error_outline),
            title: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            trailing: IconButton(
              tooltip: 'Hibaüzenet bezárása',
              onPressed: () => setState(() => _saveError = null),
              icon: const Icon(Icons.close),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 840) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 300, child: leftPanel),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: zones,
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  SizedBox(height: 320, child: leftPanel),
                  const SizedBox(height: 16),
                  zones,
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeftObstaclesPanel({required bool enabled}) {
    final filtered = _obstacleTemplates.where((t) {
      final matchesCat = _selectedCategoryKey == null ||
          t.categoryKey == _selectedCategoryKey;
      if (!matchesCat) return false;
      if (_templateQuery.isEmpty) return true;
      return t.title.toLowerCase().contains(_templateQuery) ||
          t.code.toLowerCase().contains(_templateQuery) ||
          t.technicalSpec.toLowerCase().contains(_templateQuery) ||
          t.notes.toLowerCase().contains(_templateQuery);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Akadályok (INSARAG)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Húzd át a technikai / EÜ akadályokat az asztalra vagy közvetlenül egy pályára.',
            style: TextStyle(fontSize: 12, color: HunorColors.muted),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: enabled ? () => _editObstacle() : null,
            icon: const Icon(Icons.construction),
            label: const Text('Új egyedi akadály'),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Akadály keresése (pl. vágás, dúcolás)',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (text) =>
                setState(() => _templateQuery = text.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            value: _selectedCategoryKey,
            decoration: const InputDecoration(
              labelText: 'INSARAG akadály-csoport',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Összes akadály (${_obstacleTemplates.length})'),
              ),
              for (final cat in _obstacleCategories)
                DropdownMenuItem<String?>(
                  value: cat.key,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _selectedCategoryKey = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              primary: false,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) =>
                  _templateCard(filtered[index], enabled: enabled),
            ),
          ),
        ],
      ),
    );
  }

  Widget _templateCard(_ObstacleTemplate template, {required bool enabled}) {
    final cat = _obstacleCategoryByKey(template.categoryKey);
    final card = Card(
      margin: EdgeInsets.zero,
      color: HunorColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cat.color.withValues(alpha: 0.55), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () => _addFromTemplate(template, openDialogFirst: true)
            : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: cat.color, width: 5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            template.code,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: cat.color,
                            ),
                          ),
                        ),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: cat.color.withValues(alpha: 0.9),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      template.technicalSpec,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: HunorColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: enabled ? cat.color : HunorColors.muted,
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<_ObstacleTemplate>(
      data: template,
      maxSimultaneousDrags: enabled ? 1 : 0,
      feedback: planningDragFeedback(template.title, accentColor: cat.color),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }

  Widget _buildZones(BuildContext context, ExerciseDetails details) {
    final obstacles = details.bubbles.where(_isObstacleBubble).toList();
    final bySector = <String?, List<ExerciseBubble>>{};
    for (final item in obstacles) {
      bySector.putIfAbsent(item.sectorId, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Összes felvett akadály: ${obstacles.length} db',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: HunorColors.gold,
          ),
        ),
        const SizedBox(height: 10),
        _zone(
          title: _obstaclesTable,
          bubbles: bySector[null] ?? [],
          sectors: details.sectors,
        ),
        const SizedBox(height: 20),
        Text(
          'Kijelölt Pályák (Akadályok kiosztása)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (details.sectors.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            color: HunorColors.surface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: HunorColors.border),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Még nincs felvett pálya ehhez a gyakorlathoz. Hozz létre pályákat az „1. Tervezőasztal & Pályák” fülön, majd húzd be ide az akadályokat!',
                style: TextStyle(color: HunorColors.muted),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = ((constraints.maxWidth + 12) ~/ 280).clamp(1, 3);
              final width =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final sector in details.sectors)
                    SizedBox(
                      width: width,
                      child: _zone(
                        title: sector.name,
                        sector: sector,
                        sectorId: sector.id,
                        bubbles: bySector[sector.id] ?? [],
                        sectors: details.sectors,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _zone({
    required String title,
    required List<ExerciseBubble> bubbles,
    required List<ExerciseSector> sectors,
    ExerciseSector? sector,
    String? sectorId,
  }) {
    return DragTarget<Object>(
      key: ValueKey('obstacles-${sectorId ?? 'table'}'),
      onWillAcceptWithDetails: (details) {
        if (_saving) return false;
        final data = details.data;
        return switch (data) {
          ExerciseBubble() =>
            data.exerciseId == widget.exerciseId && data.sectorId != sectorId,
          _ObstacleTemplate() => true,
          _ => false,
        };
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is ExerciseBubble) _moveObstacle(data, sectorId);
        if (data is _ObstacleTemplate) {
          _addFromTemplate(data, sectorId: sectorId);
        }
      },
      builder: (context, candidates, rejected) => Card(
        margin: EdgeInsets.zero,
        color: candidates.isEmpty ? HunorColors.surface1 : HunorColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: candidates.isEmpty ? HunorColors.border : HunorColors.gold,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (sector != null && sector.icmsName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: HunorColors.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: HunorColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        'ICMS: ${sector.icmsName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: HunorColors.gold,
                        ),
                      ),
                    ),
                  ),
                ),
              if (sector != null && sector.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    sector.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HunorColors.muted,
                    ),
                  ),
                ),
              if (sectorId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${bubbles.length} akadály',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HunorColors.muted,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (bubbles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    sectorId == null
                        ? 'Húzz ide egy akadályt balról, vagy kattints az „Új egyedi akadály” gombra.'
                        : 'Húzz ide egy akadályt az asztalról vagy a bal oldali listából.',
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final bubble in bubbles)
                        SizedBox(
                          width: sectorId == null && constraints.maxWidth >= 500
                              ? (constraints.maxWidth - 8) / 2
                              : constraints.maxWidth,
                          child: _obstacleBubbleCard(bubble, sectors),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _obstacleBubbleCard(
    ExerciseBubble bubble,
    List<ExerciseSector> sectors,
  ) {
    final cat = _obstacleCategoryByKey(
      bubble.specs['obstacle_category']?.toString(),
    );
    final code = _insaragCode(bubble);
    final spec = _technicalSpec(bubble);
    final notes = _obstacleNotes(bubble);

    final card = Card(
      key: ValueKey('obstacle-${bubble.id}'),
      margin: EdgeInsets.zero,
      color: HunorColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cat.color.withValues(alpha: 0.55), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: cat.color, width: 5)),
        ),
        child: ListTile(
          title: Text(
            bubble.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (code.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: cat.color,
                          ),
                        ),
                      ),
                    if (bubble.specs['from_3d_planner'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Text(
                          '3D Terv',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    if (spec.isNotEmpty)
                      Text(
                        spec,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: HunorColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          onTap: _saving ? null : () => _editObstacle(bubble: bubble),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Akadály duplikálása',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _duplicateObstacle(bubble),
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Akadály törlése',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _deleteObstacle(bubble),
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Akadály áthelyezése',
                enabled: !_saving,
                icon: const Icon(Icons.swap_horiz),
                onSelected: (id) =>
                    _moveObstacle(bubble, id.isEmpty ? null : id),
                itemBuilder: (context) => [
                  if (bubble.sectorId != null)
                    const PopupMenuItem(
                        value: '', child: Text(_obstaclesTable)),
                  for (final s in sectors)
                    if (s.id != bubble.sectorId)
                      PopupMenuItem(value: s.id, child: Text(s.name)),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<ExerciseBubble>(
      data: bubble,
      maxSimultaneousDrags: _saving ? 0 : 1,
      feedback: planningDragFeedback(bubble.title, accentColor: cat.color),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }
}

class _ObstacleDialog extends StatefulWidget {
  const _ObstacleDialog({this.bubble, this.template});

  final ExerciseBubble? bubble;
  final _ObstacleTemplate? template;

  @override
  State<_ObstacleDialog> createState() => _ObstacleDialogState();
}

class _ObstacleDialogState extends State<_ObstacleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late String _categoryKey;
  late final TextEditingController _code;
  late final TextEditingController _spec;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final b = widget.bubble;
    final t = widget.template;
    _title = TextEditingController(text: b?.title ?? t?.title ?? '');
    _categoryKey = b?.specs['obstacle_category']?.toString() ??
        t?.categoryKey ??
        'breaching';
    _code = TextEditingController(
      text: (b?.specs['insarag_code'] ?? t?.code ?? '').toString(),
    );
    _spec = TextEditingController(
      text: (b?.specs['technical_spec'] ?? t?.technicalSpec ?? '').toString(),
    );
    _notes = TextEditingController(
      text: (b?.specs['obstacle_notes'] ?? t?.notes ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _code.dispose();
    _spec.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _ObstacleEdit(
        title: _title.text.trim(),
        categoryKey: _categoryKey,
        insaragCode: _code.text.trim(),
        technicalSpec: _spec.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.bubble != null;
    return AlertDialog(
      title: Text(editing ? 'Akadály szerkesztése' : 'Új akadály buborék'),
      content: SizedBox(
        width: 460,
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
                    labelText: 'Akadály megnevezése *',
                    hintText: 'pl. Oldalirányú megtámasztás, Acéllemez vágás',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Add meg az akadály megnevezését.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _categoryKey,
                  decoration: const InputDecoration(
                    labelText: 'INSARAG akadály-csoport',
                  ),
                  items: [
                    for (final cat in _obstacleCategories)
                      DropdownMenuItem(
                        value: cat.key,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: cat.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(cat.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _categoryKey = v);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _code,
                        decoration: const InputDecoration(
                          labelText: 'INSARAG kód',
                          hintText: 'pl. 14.9.7',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _spec,
                        decoration: const InputDecoration(
                          labelText: 'Műszaki paraméter',
                          hintText: 'pl. 200 mm beton, 20 mm acéllemez',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Helyszíni megjegyzés / beépítési részletek',
                    hintText: 'Elhelyezkedés, előkészítés, biztonsági feltételek...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const _ObstacleEdit(
                title: '',
                categoryKey: 'breaching',
                insaragCode: '',
                technicalSpec: '',
                notes: '',
                delete: true,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Törlés'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? 'Mentés' : 'Felvétel az asztalra'),
        ),
      ],
    );
  }
}
