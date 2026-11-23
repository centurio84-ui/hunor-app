import 'package:flutter/material.dart';

import '../../theme/hunor_theme.dart';
import 'planning_bubble_dialog.dart';
import 'planning_catalog_panel.dart';
import 'planning_discipline_badge.dart';
import 'planning_models.dart';
import 'planning_repository.dart';

const _sharedGoals = 'Közös Célok Asztala';

class PlanningBoard extends StatefulWidget {
  const PlanningBoard({
    super.key,
    required this.exerciseId,
    required this.repository,
    this.onSavingChanged,
  });

  final String exerciseId;
  final PlanningRepository repository;
  final ValueChanged<bool>? onSavingChanged;

  @override
  State<PlanningBoard> createState() => _PlanningBoardState();
}

class _PlanningBoardState extends State<PlanningBoard> {
  ExerciseDetails? _details;
  bool _loadFailed = false;
  bool _saving = false;
  String? _saveError;
  BubbleDiscipline? _disciplineFilter;

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

  Future<void> _addCheckpoint(InsaragCheckpoint checkpoint) => _save(
        (details) async {
          final bubble = await widget.repository.addBubble(
            exerciseId: widget.exerciseId,
            title: checkpoint.titleHu,
            checkpointId: checkpoint.id,
            estimatedHours: checkpoint.defaultDurationHours,
          );
          return (
            sectors: details.sectors,
            bubbles: [...details.bubbles, bubble]
          );
        },
        'Az ellenőrzőpont hozzáadása nem sikerült.',
      );

  Future<void> _editBubble({
    ExerciseBubble? bubble,
    BubbleDiscipline initialDiscipline = BubbleDiscipline.custom,
  }) async {
    final edit = await showDialog<PlanningBubbleEdit>(
      context: context,
      builder: (_) => PlanningBubbleDialog(
        bubble: bubble,
        initialDiscipline: initialDiscipline,
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

        if (bubble == null) {
          final added = await widget.repository.addBubble(
            exerciseId: widget.exerciseId,
            title: edit.title,
            discipline: edit.discipline,
            estimatedHours: edit.estimatedHours,
            specs: edit.specs,
          );
          return (
            sectors: details.sectors,
            bubbles: [...details.bubbles, added]
          );
        }

        final updated = await widget.repository.updateBubbleDetails(
          bubble: bubble,
          title: edit.title,
          discipline: edit.discipline,
          estimatedHours: edit.estimatedHours,
          specs: edit.specs,
        );
        return _replaceBubble(details, updated);
      },
      edit.delete
          ? 'A buborék törlése nem sikerült.'
          : 'A buborék mentése nem sikerült.',
    );
  }

  Future<void> _moveBubble(ExerciseBubble bubble, String? sectorId) async {
    if (bubble.exerciseId != widget.exerciseId || bubble.sectorId == sectorId)
      return;
    await _save(
      (details) async => _replaceBubble(
        details,
        await widget.repository.moveBubble(bubble, sectorId),
      ),
      'A buborék áthelyezése nem sikerült.',
    );
  }

  ExerciseDetails _replaceBubble(
          ExerciseDetails details, ExerciseBubble updated) =>
      (
        sectors: details.sectors,
        bubbles: [
          for (final bubble in details.bubbles)
            if (bubble.id == updated.id) updated else bubble,
        ],
      );

  Future<void> _addSector() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Új pálya'),
        content: const Text('Létrehozod a következő sorszámú ROM pályát?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Létrehozás'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _save(
      (details) async {
        final sector = await widget.repository.createSector(widget.exerciseId);
        return (
          sectors: [...details.sectors, sector],
          bubbles: details.bubbles
        );
      },
      'A pálya létrehozása nem sikerült.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final catalog = PlanningCatalogPanel(
      repository: widget.repository,
      enabled: details != null && !_saving,
      onAddCustom: () => _editBubble(),
      onAddCheckpoint: _addCheckpoint,
    );

    final Widget zones;
    if (_loadFailed) {
      zones = Column(
        children: [
          const Text('A tervezőtábla betöltése nem sikerült.'),
          TextButton(
              onPressed: _loadDetails, child: const Text('Újrapróbálás')),
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
            title: Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                    SizedBox(width: 300, child: catalog),
                    const VerticalDivider(width: 1),
                    Expanded(
                        child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: zones,
                    )),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  SizedBox(height: 320, child: catalog),
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

  Widget _buildZones(BuildContext context, ExerciseDetails details) {
    final bySector = <String?, List<ExerciseBubble>>{};
    for (final bubble in details.bubbles) {
      bySector.putIfAbsent(bubble.sectorId, () => []).add(bubble);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _saving
                  ? null
                  : () => _editBubble(
                        initialDiscipline: BubbleDiscipline.medical,
                      ),
              icon: const Icon(Icons.add),
              label: const Text('Új szakági buborék'),
            ),
            PopupMenuButton<String>(
              tooltip: 'Szűrés szakág szerint',
              initialValue: _disciplineFilter?.value ?? '',
              onSelected: (value) => setState(() {
                _disciplineFilter =
                    value.isEmpty ? null : BubbleDiscipline.fromValue(value);
              }),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('Minden szakág')),
                for (final discipline in BubbleDiscipline.values)
                  PopupMenuItem(
                      value: discipline.value, child: Text(discipline.label)),
              ],
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_disciplineFilter?.label ?? 'Minden szakág'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _zone(
            title: _sharedGoals,
            bubbles: bySector[null] ?? [],
            sectors: details.sectors),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text('Kijelölt Pályák',
                style: Theme.of(context).textTheme.titleLarge),
            OutlinedButton.icon(
              onPressed: _saving ? null : _addSector,
              icon: const Icon(Icons.add),
              label: const Text('Új pálya'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = ((constraints.maxWidth + 12) ~/ 260).clamp(1, 3);
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final sector in details.sectors)
                  SizedBox(
                    width: width,
                    child: _zone(
                      title: sector.name,
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
    String? sectorId,
  }) {
    final total = bubbles.fold<double>(
        0, (sum, item) => sum + (item.estimatedHours ?? 0));
    final visible = bubbles.where((bubble) =>
        _disciplineFilter == null || bubble.discipline == _disciplineFilter);
    return DragTarget<Object>(
      key: ValueKey(sectorId ?? 'shared-goals'),
      onWillAcceptWithDetails: (details) {
        if (_saving) return false;
        final data = details.data;
        return switch (data) {
          ExerciseBubble() =>
            data.exerciseId == widget.exerciseId && data.sectorId != sectorId,
          InsaragCheckpoint() => sectorId == null,
          _ => false,
        };
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is ExerciseBubble) _moveBubble(data, sectorId);
        if (data is InsaragCheckpoint) _addCheckpoint(data);
      },
      builder: (context, candidates, rejected) => Card(
        margin: EdgeInsets.zero,
        color: candidates.isEmpty ? HunorColors.surface1 : HunorColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color:
                  candidates.isEmpty ? HunorColors.border : HunorColors.gold),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (sectorId != null)
                Text(
                    '${bubbles.length} buborék · ${planningHours(double.parse(total.toStringAsPrecision(12)))} óra'),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(_disciplineFilter != null
                      ? 'Nincs ilyen szakágú buborék.'
                      : sectorId == null
                          ? 'Húzz ide egy célt a katalógusból.'
                          : 'Húzz ide egy buborékot.'),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final bubble in visible)
                        SizedBox(
                          width: sectorId == null && constraints.maxWidth >= 500
                              ? (constraints.maxWidth - 8) / 2
                              : constraints.maxWidth,
                          child: _bubbleCard(bubble, sectors),
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

  Widget _bubbleCard(ExerciseBubble bubble, List<ExerciseSector> sectors) {
    final card = Card(
      key: ValueKey(bubble.id),
      margin: EdgeInsets.zero,
      color: HunorColors.surface2,
      child: ListTile(
        title: Text(bubble.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PlanningDisciplineBadge(bubble.discipline),
              Text(bubble.estimatedHours == null
                  ? 'Nincs időbecslés'
                  : '${planningHours(bubble.estimatedHours!)} óra'),
            ],
          ),
        ),
        onTap: _saving ? null : () => _editBubble(bubble: bubble),
        trailing: PopupMenuButton<String>(
          tooltip: 'Buborék áthelyezése',
          enabled: !_saving,
          icon: const Icon(Icons.swap_horiz),
          onSelected: (id) => _moveBubble(bubble, id.isEmpty ? null : id),
          itemBuilder: (context) => [
            if (bubble.sectorId != null)
              const PopupMenuItem(value: '', child: Text(_sharedGoals)),
            for (final sector in sectors)
              if (sector.id != bubble.sectorId)
                PopupMenuItem(value: sector.id, child: Text(sector.name)),
          ],
        ),
      ),
    );

    return Draggable<ExerciseBubble>(
      data: bubble,
      maxSimultaneousDrags: _saving ? 0 : 1,
      feedback: planningDragFeedback(bubble.title),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }
}
