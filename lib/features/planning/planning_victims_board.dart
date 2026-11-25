import 'package:flutter/material.dart';

import '../../theme/hunor_theme.dart';
import 'planning_catalog_panel.dart';
import 'planning_models.dart';
import 'planning_repository.dart';

const _victimsTable = 'Sérültek Asztala';

class _VictimTemplate {
  const _VictimTemplate({
    required this.title,
    required this.injuryType,
    required this.defaultCareNotes,
    required this.color,
    this.defaultCount = 1,
  });

  final String title;
  final String injuryType;
  final String defaultCareNotes;
  final Color color;
  final int defaultCount;
}

const List<_VictimTemplate> _victimTemplates = [
  _VictimTemplate(
    title: 'Crush-szindrómás sérült',
    injuryType: 'Crush-szindróma',
    defaultCareNotes:
        'Szűk téri stabilizálás, vénabiztosítás, folyadékterápia, monitorozás kiszabadítás előtt.',
    color: Color(0xFFDC2626),
  ),
  _VictimTemplate(
    title: 'Terepi amputáció (szűk tér)',
    injuryType: 'Terepi amputáció',
    defaultCareNotes:
        'Fájdalomcsillapítás, szedálás/anesztézia, érszorító, steril ellátás, gyors kiemelés.',
    color: Color(0xFF991B1B),
  ),
  _VictimTemplate(
    title: 'Eszméletlen, beszorult sérült',
    injuryType: 'Eszméletlen / beszorult',
    defaultCareNotes:
        'Légútbiztosítás, oxigén, gerincrögzítés, hővédelem, PPE felhelyezése a sérültre.',
    color: Color(0xFFEA580C),
  ),
  _VictimTemplate(
    title: 'Polytrauma / erős vérzés',
    injuryType: 'Polytrauma / vérzés',
    defaultCareNotes:
        'Vérzéscsillapítás (tourniquet / nyomókötés), sokktalanítás, hordágyas kimenekítés.',
    color: Color(0xFFE11D48),
  ),
  _VictimTemplate(
    title: 'Zárt / nyílt végtagtörés',
    injuryType: 'Zárt / nyílt törés',
    defaultCareNotes:
        'Törésrögzítés (sín), fájdalomcsillapítás, sebfedés, kíméletes szállítás.',
    color: Color(0xFFD97706),
  ),
  _VictimTemplate(
    title: 'Égési sérült',
    injuryType: 'Égési sérülés',
    defaultCareNotes:
        'Hűtés, steril fedés, légúti égés ellenőrzése, folyadékpótlás és fájdalomcsillapítás.',
    color: Color(0xFFF59E0B),
  ),
  _VictimTemplate(
    title: 'Füstmérgezés / légúti sérült',
    injuryType: 'Füstmérgezés / légúti',
    defaultCareNotes:
        'Magas áramlású oxigén, légúti monitorozás, azonnali kihozatal friss levegőre.',
    color: Color(0xFF0284C7),
  ),
  _VictimTemplate(
    title: 'Sérült keresőkutya (K9)',
    injuryType: 'K9 állatorvosi sérült',
    defaultCareNotes:
        'Kutyavezetővel együttműködve sürgősségi állatorvosi ellátás és elszállítás BoO-ra.',
    color: Color(0xFF7C3AED),
  ),
  _VictimTemplate(
    title: 'Elhunyt személy (Black tag)',
    injuryType: 'Elhunyt (Black tag)',
    defaultCareNotes:
        'INSARAG jelölés frissítése, LEMA / hatóság értesítése, dokumentáció.',
    color: Color(0xFF475569),
  ),
];

class _VictimEdit {
  const _VictimEdit({
    required this.title,
    required this.patientCount,
    required this.injuryType,
    required this.careNotes,
    this.delete = false,
  });

  final String title;
  final int patientCount;
  final String injuryType;
  final String careNotes;
  final bool delete;
}

class PlanningVictimsBoard extends StatefulWidget {
  const PlanningVictimsBoard({
    super.key,
    required this.exerciseId,
    required this.repository,
    this.onSavingChanged,
  });

  final String exerciseId;
  final PlanningRepository repository;
  final ValueChanged<bool>? onSavingChanged;

  @override
  State<PlanningVictimsBoard> createState() => _PlanningVictimsBoardState();
}

class _PlanningVictimsBoardState extends State<PlanningVictimsBoard> {
  ExerciseDetails? _details;
  bool _loadFailed = false;
  bool _saving = false;
  String? _saveError;
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

  int _patientCount(ExerciseBubble bubble) {
    final raw = bubble.specs['patient_count'];
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw > 0) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 1;
  }

  String _injuryType(ExerciseBubble bubble) =>
      bubble.specs['injury_type']?.toString().trim() ?? '';

  String _careNotes(ExerciseBubble bubble) =>
      bubble.specs['care_notes']?.toString().trim() ?? '';

  Color _victimColor(ExerciseBubble bubble) {
    final type = _injuryType(bubble).toLowerCase();
    for (final t in _victimTemplates) {
      if (type.contains(t.injuryType.toLowerCase()) ||
          t.injuryType.toLowerCase().contains(type) && type.isNotEmpty) {
        return t.color;
      }
    }
    return const Color(0xFFDC2626);
  }

  Future<void> _addFromTemplate(
    _VictimTemplate template, {
    String? sectorId,
    bool openDialogFirst = false,
  }) async {
    if (openDialogFirst) {
      await _editVictim(template: template, initialSectorId: sectorId);
      return;
    }
    await _save(
      (details) async {
        final added = await widget.repository.addBubble(
          exerciseId: widget.exerciseId,
          sectorId: sectorId,
          title: template.title,
          discipline: BubbleDiscipline.medical,
          estimatedHours: null,
          specs: {
            'injury_type': template.injuryType,
            'patient_count': template.defaultCount,
            'care_notes': template.defaultCareNotes,
          },
        );
        return (
          sectors: details.sectors,
          bubbles: [...details.bubbles, added],
        );
      },
      'A sérült buborék felvétele nem sikerült.',
    );
  }

  Future<void> _editVictim({
    ExerciseBubble? bubble,
    _VictimTemplate? template,
    String? initialSectorId,
  }) async {
    final edit = await showDialog<_VictimEdit>(
      context: context,
      builder: (_) => _VictimDialog(
        bubble: bubble,
        template: template,
      ),
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
          'injury_type': edit.injuryType,
          'patient_count': edit.patientCount,
          'care_notes': edit.careNotes,
        };

        if (bubble == null) {
          final added = await widget.repository.addBubble(
            exerciseId: widget.exerciseId,
            sectorId: initialSectorId,
            title: edit.title,
            discipline: BubbleDiscipline.medical,
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
          discipline: BubbleDiscipline.medical,
          estimatedHours: bubble.estimatedHours,
          title: edit.title,
          specs: specs,
        );
        return _replaceBubble(details, updated);
      },
      edit.delete
          ? 'A sérült buborék törlése nem sikerült.'
          : 'A sérült buborék mentése nem sikerült.',
    );
  }

  Future<void> _deleteVictim(ExerciseBubble bubble) => _save(
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
        'A sérült buborék törlése nem sikerült.',
      );

  Future<void> _duplicateVictim(ExerciseBubble bubble) => _save(
        (details) async {
          final copy = await widget.repository.addBubble(
            exerciseId: widget.exerciseId,
            sectorId: bubble.sectorId,
            title: bubble.title,
            discipline: BubbleDiscipline.medical,
            estimatedHours: null,
            specs: Map<String, dynamic>.from(bubble.specs),
          );
          return (
            sectors: details.sectors,
            bubbles: [...details.bubbles, copy],
          );
        },
        'A sérült buborék duplikálása nem sikerült.',
      );

  Future<void> _moveVictim(ExerciseBubble bubble, String? sectorId) async {
    if (bubble.exerciseId != widget.exerciseId || bubble.sectorId == sectorId) {
      return;
    }
    await _save(
      (details) async => _replaceBubble(
        details,
        await widget.repository.moveBubble(bubble, sectorId),
      ),
      'A sérült áthelyezése nem sikerült.',
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
    final leftPanel = _buildLeftVictimsPanel(enabled: details != null && !_saving);

    final Widget zones;
    if (_loadFailed) {
      zones = Column(
        children: [
          const Text('A sérült-tábla betöltése nem sikerült.'),
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

  Widget _buildLeftVictimsPanel({required bool enabled}) {
    final filtered = _victimTemplates.where((t) {
      if (_templateQuery.isEmpty) return true;
      return t.title.toLowerCase().contains(_templateQuery) ||
          t.injuryType.toLowerCase().contains(_templateQuery) ||
          t.defaultCareNotes.toLowerCase().contains(_templateQuery);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sérültek', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Vegyél fel egyedi sérültet, vagy húzz át egy sablont az asztalra / pályára.',
            style: TextStyle(fontSize: 12, color: HunorColors.muted),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: enabled ? () => _editVictim() : null,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Új sérült buborék'),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Sérülés típus keresése',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (text) =>
                setState(() => _templateQuery = text.trim().toLowerCase()),
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

  Widget _templateCard(_VictimTemplate template, {required bool enabled}) {
    final card = Card(
      margin: EdgeInsets.zero,
      color: HunorColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: template.color.withValues(alpha: 0.55), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () => _addFromTemplate(template, openDialogFirst: true)
            : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: template.color, width: 5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      template.defaultCareNotes,
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
                color: enabled ? template.color : HunorColors.muted,
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<_VictimTemplate>(
      data: template,
      maxSimultaneousDrags: enabled ? 1 : 0,
      feedback: planningDragFeedback(template.title, accentColor: template.color),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }

  Widget _buildZones(BuildContext context, ExerciseDetails details) {
    final victims = details.bubbles
        .where((b) => b.discipline == BubbleDiscipline.medical)
        .toList();
    final bySector = <String?, List<ExerciseBubble>>{};
    for (final v in victims) {
      bySector.putIfAbsent(v.sectorId, () => []).add(v);
    }
    final totalPatients =
        victims.fold<int>(0, (sum, b) => sum + _patientCount(b));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Összes felvett sérült: ${victims.length} buborék · $totalPatients fő',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: HunorColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _zone(
          title: _victimsTable,
          bubbles: bySector[null] ?? [],
          sectors: details.sectors,
        ),
        const SizedBox(height: 20),
        Text(
          'Kijelölt Pályák (Sérültek kiosztása)',
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
                'Még nincs felvett pálya ehhez a gyakorlathoz. Hozz létre pályákat a „Tervezőasztal & Pályák” fülön, majd húzd be ide a sérülteket!',
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
    final totalPatients =
        bubbles.fold<int>(0, (sum, item) => sum + _patientCount(item));

    return DragTarget<Object>(
      key: ValueKey('victims-${sectorId ?? 'table'}'),
      onWillAcceptWithDetails: (details) {
        if (_saving) return false;
        final data = details.data;
        return switch (data) {
          ExerciseBubble() =>
            data.exerciseId == widget.exerciseId && data.sectorId != sectorId,
          _VictimTemplate() => true,
          _ => false,
        };
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is ExerciseBubble) _moveVictim(data, sectorId);
        if (data is _VictimTemplate) {
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
                    '${bubbles.length} buborék · $totalPatients fő sérült',
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
                        ? 'Húzz ide egy sérült buborékot balról, vagy kattints az „Új sérült buborék” gombra.'
                        : 'Húzz ide egy sérültet az asztalról vagy a bal oldali listából.',
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
                          child: _victimBubbleCard(bubble, sectors),
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

  Widget _victimBubbleCard(
    ExerciseBubble bubble,
    List<ExerciseSector> sectors,
  ) {
    final accent = _victimColor(bubble);
    final count = _patientCount(bubble);
    final injury = _injuryType(bubble);
    final notes = _careNotes(bubble);

    final card = Card(
      key: ValueKey('victim-${bubble.id}'),
      margin: EdgeInsets.zero,
      color: HunorColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.55), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 5)),
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
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$count fő',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    if (injury.isNotEmpty)
                      Text(
                        injury,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (bubble.specs['placed_3d'] == true)
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
                        child: Text(
                          '3D: ${bubble.specs['container_3d_label'] ?? 'Elhelyezve'}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF38BDF8),
                          ),
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
          onTap: _saving ? null : () => _editVictim(bubble: bubble),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Sérült buborék duplikálása',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _duplicateVictim(bubble),
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Sérült buborék törlése',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _deleteVictim(bubble),
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Sérült áthelyezése',
                enabled: !_saving,
                icon: const Icon(Icons.swap_horiz),
                onSelected: (id) =>
                    _moveVictim(bubble, id.isEmpty ? null : id),
                itemBuilder: (context) => [
                  if (bubble.sectorId != null)
                    const PopupMenuItem(value: '', child: Text(_victimsTable)),
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
      feedback: planningDragFeedback(
        '${bubble.title} ($count fő)',
        accentColor: accent,
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }
}

class _VictimDialog extends StatefulWidget {
  const _VictimDialog({this.bubble, this.template});

  final ExerciseBubble? bubble;
  final _VictimTemplate? template;

  @override
  State<_VictimDialog> createState() => _VictimDialogState();
}

class _VictimDialogState extends State<_VictimDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _count;
  late final TextEditingController _injuryType;
  late final TextEditingController _careNotes;

  @override
  void initState() {
    super.initState();
    final b = widget.bubble;
    final t = widget.template;
    _title = TextEditingController(text: b?.title ?? t?.title ?? '');
    _count = TextEditingController(
      text: (b?.specs['patient_count'] ?? t?.defaultCount ?? 1).toString(),
    );
    _injuryType = TextEditingController(
      text: b?.specs['injury_type']?.toString() ?? t?.injuryType ?? '',
    );
    _careNotes = TextEditingController(
      text: b?.specs['care_notes']?.toString() ?? t?.defaultCareNotes ?? '',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _count.dispose();
    _injuryType.dispose();
    _careNotes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final count = int.parse(_count.text.trim());
    final injury = _injuryType.text.trim();
    final title = _title.text.trim().isNotEmpty ? _title.text.trim() : injury;
    Navigator.pop(
      context,
      _VictimEdit(
        title: title,
        patientCount: count,
        injuryType: injury,
        careNotes: _careNotes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.bubble != null;
    return AlertDialog(
      title: Text(editing ? 'Sérült szerkesztése' : 'Új sérült buborék'),
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
                    labelText: 'Sérült megnevezése / azonosítója *',
                    hintText: 'pl. Sérült #1 – Pince beszorult',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Add meg a sérült megnevezését.'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        controller: _count,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sérültek száma (fő) *',
                        ),
                        validator: (value) {
                          final n = int.tryParse(value?.trim() ?? '');
                          if (n == null || n < 1) {
                            return 'Min. 1 fő';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _injuryType,
                        decoration: const InputDecoration(
                          labelText: 'Sérülés típusa *',
                          hintText: 'pl. Crush-szindróma, nyílt törés',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Add meg a sérülés típusát.'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _careNotes,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'További teendők / ellátási és kimenekítési terv',
                    hintText:
                        'pl. Vénabiztosítás, fájdalomcsillapítás, gerincrögzítés, PPE...',
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
              const _VictimEdit(
                title: '',
                patientCount: 1,
                injuryType: '',
                careNotes: '',
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
