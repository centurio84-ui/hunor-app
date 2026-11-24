import 'package:flutter/material.dart';

import '../../theme/hunor_theme.dart';
import 'planning_catalog_panel.dart';
import 'planning_models.dart';
import 'planning_repository.dart';

const _injectsTable = 'Injektek Asztala';

class _InjectCategory {
  const _InjectCategory({
    required this.key,
    required this.label,
    required this.color,
    required this.discipline,
  });

  final String key;
  final String label;
  final Color color;
  final BubbleDiscipline discipline;
}

const List<_InjectCategory> _injectCategories = [
  _InjectCategory(
    key: 'safety',
    label: 'Biztonság / Evakuálás',
    color: Color(0xFFDC2626),
    discipline: BubbleDiscipline.ucc,
  ),
  _InjectCategory(
    key: 'ucc',
    label: 'UCC / Törzs / Koordináció',
    color: Color(0xFF2563EB),
    discipline: BubbleDiscipline.ucc,
  ),
  _InjectCategory(
    key: 'press_vip',
    label: 'Sajtó / VIP / LEMA',
    color: Color(0xFFC026D3),
    discipline: BubbleDiscipline.pressVip,
  ),
  _InjectCategory(
    key: 'hazard',
    label: 'Műszaki / Veszély / Hazmat',
    color: Color(0xFFEA580C),
    discipline: BubbleDiscipline.ucc,
  ),
  _InjectCategory(
    key: 'medical_inject',
    label: 'Egészségügyi / MEDEVAC',
    color: Color(0xFFE11D48),
    discipline: BubbleDiscipline.ucc,
  ),
  _InjectCategory(
    key: 'comms_log',
    label: 'Kommunikáció / Logisztika',
    color: Color(0xFF0D9488),
    discipline: BubbleDiscipline.ucc,
  ),
];

_InjectCategory _categoryByKey(String? key, BubbleDiscipline fallback) {
  for (final c in _injectCategories) {
    if (c.key == key) return c;
  }
  if (fallback == BubbleDiscipline.pressVip) {
    return _injectCategories[2];
  }
  return _injectCategories[1];
}

class _InjectTemplate {
  const _InjectTemplate({
    required this.title,
    required this.categoryKey,
    required this.targetRole,
    required this.notes,
  });

  final String title;
  final String categoryKey;
  final String targetRole;
  final String notes;
}

const List<_InjectTemplate> _injectTemplates = [
  _InjectTemplate(
    title: 'Utórengés + azonnali evakuálás (14.6.2)',
    categoryKey: 'safety',
    targetRole: 'Kárhelyparancsnok & BoO',
    notes:
        'Erős utórengés szimulációja: INSARAG hangjelzés, azonnali kivonulás a gyülekezési pontra és teljes létszámellenőrzés.',
  ),
  _InjectTemplate(
    title: 'Épületmozgás / statikai riasztás (14.6.6)',
    categoryKey: 'safety',
    targetRole: 'Biztonsági tiszt / Statikus',
    notes:
        'A monitoring rendszer elmozdulást jelez; munka leállítása, dúcolások ellenőrzése, kockázat újraértékelése.',
  ),
  _InjectTemplate(
    title: 'Sajtó / TV stáb érkezése a kárhelyre',
    categoryKey: 'press_vip',
    targetRole: 'Sajtófelelős / Kárhelyparancsnok',
    notes:
        'Médiastáb próbál belépni a kordonon belülre; biztonságos kijelölt nyilatkozati pont, kíséret és hivatalos tájékoztatás.',
  ),
  _InjectTemplate(
    title: 'VIP / LEMA delegáció helyszíni látogatása',
    categoryKey: 'press_vip',
    targetRole: 'Csapatvezető / LEMA összekötő',
    notes:
        'Helyi hatóság / VIP küldöttség érkezik a kárhelyre vagy a BoO-ra; protokoll, PPE biztosítása és rövid helyzetjelentés.',
  ),
  _InjectTemplate(
    title: 'Csapattag súlyos sérülése / MEDEVAC (14.14.8)',
    categoryKey: 'medical_inject',
    targetRole: 'EÜ csoportvezető & Törzs',
    notes:
        'Saját állományhoz tartozó tag megsérül a munkaterületen; azonnali ellátás, MEDEVAC terv aktiválása, LEMA/kórház értesítés.',
  ),
  _InjectTemplate(
    title: 'K9 keresőkutya sérülés / állatorvosi eset (14.14.7)',
    categoryKey: 'medical_inject',
    targetRole: 'Kutyavezető & EÜ / Állatorvos',
    notes:
        'Keresőkutya talpsérülést vagy hőkimerülést szenved; kárhelyi elsősegély és BoO-ra szállítás.',
  ),
  _InjectTemplate(
    title: 'Gázszivárgás / Hazmat veszély a romon (13.4)',
    categoryKey: 'hazard',
    targetRole: 'Kárhelyparancsnok & UCC/LEMA',
    notes:
        'Gázérzékelő riasztás a szűk térben; behatolás megszakítása, szellőztetés, UCC-n keresztül LEMA azonnali értesítése.',
  ),
  _InjectTemplate(
    title: 'Második USAR csapat érkezése / együttműködés (14.1)',
    categoryKey: 'ucc',
    targetRole: 'UCC / Törzs',
    notes:
        'Társcsapat érkezik a szektorba; feladatmegosztás, közös híradó csatorna, biztonsági és kárhelyi koordináció.',
  ),
  _InjectTemplate(
    title: 'Internet / ICMS kimaradás (papír backup – 12.3/12.4)',
    categoryKey: 'comms_log',
    targetRole: 'RDC / UCC személyzet',
    notes:
        'Hálózati kapcsolat megszűnik; átállás papír alapú INSARAG nyomtatványokra és táblás adatkezelésre.',
  ),
  _InjectTemplate(
    title: 'Rádiófrekvencia-váltás / klónozás (7.1.1)',
    categoryKey: 'comms_log',
    targetRole: 'Híradó tiszt',
    notes:
        'Helyi hatóság új frekvenciát jelöl ki; rádiók klónozása és kommunikációs próba végrehajtása.',
  ),
  _InjectTemplate(
    title: 'Demobilizációs egyeztetés UCC/LEMA és RDC felé (15.2)',
    categoryKey: 'ucc',
    targetRole: 'Csapatvezető / UCC',
    notes:
        'Mentési fázis zárása, kivonulási terv egyeztetése, Fact Sheet és Mission Summary Report leadása.',
  ),
  _InjectTemplate(
    title: 'Hazai / diplomáciai képviselő megkeresése (15.5)',
    categoryKey: 'press_vip',
    targetRole: 'Csapatvezető',
    notes:
        'Konzul / nagykövetségi képviselő egyeztet a csapat biztonságáról és hazautazási ütemezéséről.',
  ),
];

class _InjectEdit {
  const _InjectEdit({
    required this.title,
    required this.categoryKey,
    required this.targetRole,
    required this.notes,
    this.delete = false,
  });

  final String title;
  final String categoryKey;
  final String targetRole;
  final String notes;
  final bool delete;
}

class PlanningInjectsBoard extends StatefulWidget {
  const PlanningInjectsBoard({
    super.key,
    required this.exerciseId,
    required this.repository,
    this.onSavingChanged,
  });

  final String exerciseId;
  final PlanningRepository repository;
  final ValueChanged<bool>? onSavingChanged;

  @override
  State<PlanningInjectsBoard> createState() => _PlanningInjectsBoardState();
}

class _PlanningInjectsBoardState extends State<PlanningInjectsBoard> {
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

  bool _isInjectBubble(ExerciseBubble b) =>
      b.specs['is_inject'] == true ||
      b.discipline == BubbleDiscipline.ucc ||
      b.discipline == BubbleDiscipline.pressVip;

  String _targetRole(ExerciseBubble b) =>
      (b.specs['target_role'] ?? b.specs['role_or_team'] ?? b.specs['stakeholder_type'] ?? '')
          .toString()
          .trim();

  String _injectNotes(ExerciseBubble b) =>
      (b.specs['inject_notes'] ?? b.specs['coordination_notes'] ?? b.specs['protocol_notes'] ?? '')
          .toString()
          .trim();

  Future<void> _addFromTemplate(
    _InjectTemplate template, {
    String? sectorId,
    bool openDialogFirst = false,
  }) async {
    if (openDialogFirst) {
      await _editInject(template: template, initialSectorId: sectorId);
      return;
    }
    final cat = _categoryByKey(template.categoryKey, BubbleDiscipline.ucc);
    await _save(
      (details) async {
        final added = await widget.repository.addBubble(
          exerciseId: widget.exerciseId,
          sectorId: sectorId,
          title: template.title,
          discipline: cat.discipline,
          estimatedHours: null,
          specs: {
            'is_inject': true,
            'inject_category': cat.key,
            'target_role': template.targetRole,
            'inject_notes': template.notes,
          },
        );
        return (
          sectors: details.sectors,
          bubbles: [...details.bubbles, added],
        );
      },
      'Az injekt buborék felvétele nem sikerült.',
    );
  }

  Future<void> _editInject({
    ExerciseBubble? bubble,
    _InjectTemplate? template,
    String? initialSectorId,
  }) async {
    final edit = await showDialog<_InjectEdit>(
      context: context,
      builder: (_) => _InjectDialog(bubble: bubble, template: template),
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

        final cat = _categoryByKey(edit.categoryKey, BubbleDiscipline.ucc);
        final specs = <String, dynamic>{
          if (bubble != null) ...bubble.specs,
          'is_inject': true,
          'inject_category': cat.key,
          'target_role': edit.targetRole,
          'inject_notes': edit.notes,
        };

        if (bubble == null) {
          final added = await widget.repository.addBubble(
            exerciseId: widget.exerciseId,
            sectorId: initialSectorId,
            title: edit.title,
            discipline: cat.discipline,
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
          discipline: cat.discipline,
          estimatedHours: bubble.estimatedHours,
          title: edit.title,
          specs: specs,
        );
        return _replaceBubble(details, updated);
      },
      edit.delete
          ? 'Az injekt törlése nem sikerült.'
          : 'Az injekt mentése nem sikerült.',
    );
  }

  Future<void> _deleteInject(ExerciseBubble bubble) => _save(
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
        'Az injekt törlése nem sikerült.',
      );

  Future<void> _duplicateInject(ExerciseBubble bubble) => _save(
        (details) async {
          final copy = await widget.repository.addBubble(
            exerciseId: widget.exerciseId,
            sectorId: bubble.sectorId,
            title: bubble.title,
            discipline: bubble.discipline,
            estimatedHours: null,
            specs: {
              ...bubble.specs,
              'is_inject': true,
            },
          );
          return (
            sectors: details.sectors,
            bubbles: [...details.bubbles, copy],
          );
        },
        'Az injekt duplikálása nem sikerült.',
      );

  Future<void> _moveInject(ExerciseBubble bubble, String? sectorId) async {
    if (bubble.exerciseId != widget.exerciseId || bubble.sectorId == sectorId) {
      return;
    }
    await _save(
      (details) async => _replaceBubble(
        details,
        await widget.repository.moveBubble(bubble, sectorId),
      ),
      'Az injekt áthelyezése nem sikerült.',
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
        _buildLeftInjectsPanel(enabled: details != null && !_saving);

    final Widget zones;
    if (_loadFailed) {
      zones = Column(
        children: [
          const Text('Az injekt-tábla betöltése nem sikerült.'),
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

  Widget _buildLeftInjectsPanel({required bool enabled}) {
    final filtered = _injectTemplates.where((t) {
      final matchesCat = _selectedCategoryKey == null ||
          t.categoryKey == _selectedCategoryKey;
      if (!matchesCat) return false;
      if (_templateQuery.isEmpty) return true;
      return t.title.toLowerCase().contains(_templateQuery) ||
          t.targetRole.toLowerCase().contains(_templateQuery) ||
          t.notes.toLowerCase().contains(_templateQuery);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Injektek', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Vegyél fel egyedi injektet, vagy húzz át egy sablont az asztalra / pályára.',
            style: TextStyle(fontSize: 12, color: HunorColors.muted),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: enabled ? () => _editInject() : null,
            icon: const Icon(Icons.bolt),
            label: const Text('Új injekt buborék'),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Injekt keresése',
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
              labelText: 'Injekt kategória',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Összes kategória (${_injectTemplates.length})'),
              ),
              for (final cat in _injectCategories)
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

  Widget _templateCard(_InjectTemplate template, {required bool enabled}) {
    final cat = _categoryByKey(template.categoryKey, BubbleDiscipline.ucc);
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: cat.color,
                        ),
                      ),
                    ),
                    Text(
                      template.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      template.notes,
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

    return Draggable<_InjectTemplate>(
      data: template,
      maxSimultaneousDrags: enabled ? 1 : 0,
      feedback: planningDragFeedback(template.title, accentColor: cat.color),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }

  Widget _buildZones(BuildContext context, ExerciseDetails details) {
    final injects = details.bubbles.where(_isInjectBubble).toList();
    final bySector = <String?, List<ExerciseBubble>>{};
    for (final item in injects) {
      bySector.putIfAbsent(item.sectorId, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Összes felvett injekt: ${injects.length} db',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: HunorColors.gold,
          ),
        ),
        const SizedBox(height: 10),
        _zone(
          title: _injectsTable,
          bubbles: bySector[null] ?? [],
          sectors: details.sectors,
        ),
        const SizedBox(height: 20),
        Text(
          'Kijelölt Pályák (Injektek kiosztása)',
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
                'Még nincs felvett pálya ehhez a gyakorlathoz. Hozz létre pályákat az „1. Tervezőasztal & Pályák” fülön, majd húzd be ide az injekteket!',
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
      key: ValueKey('injects-${sectorId ?? 'table'}'),
      onWillAcceptWithDetails: (details) {
        if (_saving) return false;
        final data = details.data;
        return switch (data) {
          ExerciseBubble() =>
            data.exerciseId == widget.exerciseId && data.sectorId != sectorId,
          _InjectTemplate() => true,
          _ => false,
        };
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is ExerciseBubble) _moveInject(data, sectorId);
        if (data is _InjectTemplate) {
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
                    '${bubbles.length} injekt',
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
                        ? 'Húzz ide egy injekt buborékot balról, vagy kattints az „Új injekt buborék” gombra.'
                        : 'Húzz ide egy injektet az asztalról vagy a bal oldali listából.',
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
                          child: _injectBubbleCard(bubble, sectors),
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

  Widget _injectBubbleCard(
    ExerciseBubble bubble,
    List<ExerciseSector> sectors,
  ) {
    final cat = _categoryByKey(
      bubble.specs['inject_category']?.toString(),
      bubble.discipline,
    );
    final role = _targetRole(bubble);
    final notes = _injectNotes(bubble);

    final card = Card(
      key: ValueKey('inject-${bubble.id}'),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: cat.color,
                        ),
                      ),
                    ),
                    if (role.isNotEmpty)
                      Text(
                        'Célpont: $role',
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
          onTap: _saving ? null : () => _editInject(bubble: bubble),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Injekt duplikálása',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _duplicateInject(bubble),
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Injekt törlése',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _deleteInject(bubble),
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Injekt áthelyezése',
                enabled: !_saving,
                icon: const Icon(Icons.swap_horiz),
                onSelected: (id) =>
                    _moveInject(bubble, id.isEmpty ? null : id),
                itemBuilder: (context) => [
                  if (bubble.sectorId != null)
                    const PopupMenuItem(value: '', child: Text(_injectsTable)),
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

class _InjectDialog extends StatefulWidget {
  const _InjectDialog({this.bubble, this.template});

  final ExerciseBubble? bubble;
  final _InjectTemplate? template;

  @override
  State<_InjectDialog> createState() => _InjectDialogState();
}

class _InjectDialogState extends State<_InjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late String _categoryKey;
  late final TextEditingController _targetRole;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final b = widget.bubble;
    final t = widget.template;
    _title = TextEditingController(text: b?.title ?? t?.title ?? '');
    _categoryKey = b?.specs['inject_category']?.toString() ??
        t?.categoryKey ??
        (b?.discipline == BubbleDiscipline.pressVip ? 'press_vip' : 'ucc');
    _targetRole = TextEditingController(
      text: (b?.specs['target_role'] ??
              b?.specs['role_or_team'] ??
              b?.specs['stakeholder_type'] ??
              t?.targetRole ??
              '')
          .toString(),
    );
    _notes = TextEditingController(
      text: (b?.specs['inject_notes'] ??
              b?.specs['coordination_notes'] ??
              b?.specs['protocol_notes'] ??
              t?.notes ??
              '')
          .toString(),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _targetRole.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _InjectEdit(
        title: _title.text.trim(),
        categoryKey: _categoryKey,
        targetRole: _targetRole.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.bubble != null;
    return AlertDialog(
      title: Text(editing ? 'Injekt szerkesztése' : 'Új injekt buborék'),
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
                    labelText: 'Injekt megnevezése *',
                    hintText: 'pl. Utórengés + evakuálás, Sajtó érkezése',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Add meg az injekt megnevezését.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _categoryKey,
                  decoration: const InputDecoration(
                    labelText: 'Kategória',
                  ),
                  items: [
                    for (final cat in _injectCategories)
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
                TextFormField(
                  controller: _targetRole,
                  decoration: const InputDecoration(
                    labelText: 'Célpont / érintett szereplő',
                    hintText: 'pl. Kárhelyparancsnok, UCC, LEMA, Sajtós',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Injekt leírása / elvárt reakció',
                    hintText: 'Mi történik és milyen csapatreakciót figyel az EXCON?',
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
              const _InjectEdit(
                title: '',
                categoryKey: 'ucc',
                targetRole: '',
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
