import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'planning_catalog_panel.dart' show planningHours;
import 'planning_models.dart';
import 'planning_repository.dart';
import 'planning_timeline_canvas.dart';
import 'planning_timeline_dialog.dart';

class PlanningTimelineWall extends StatefulWidget {
  const PlanningTimelineWall({
    super.key,
    required this.exerciseId,
    required this.repository,
    this.onSavingChanged,
  });

  final String exerciseId;
  final PlanningRepository repository;
  final ValueChanged<bool>? onSavingChanged;

  @override
  State<PlanningTimelineWall> createState() => _PlanningTimelineWallState();
}

class _PlanningTimelineWallState extends State<PlanningTimelineWall> {
  static const _shared = '';
  static const _all = 'all';
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _writeError;
  String _sectorFilter = _all;
  ExerciseDetails? _exercise;
  List<ExerciseTimelineBlock> _blocks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading) {
      setState(() {
        _loading = true;
        _loadError = null;
        _writeError = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        widget.repository.fetchTimeline(widget.exerciseId),
        widget.repository.fetchExerciseDetails(widget.exerciseId),
      ]);
      if (!mounted) return;
      final exercise = results[1] as ExerciseDetails;
      setState(() {
        _blocks = results[0] as List<ExerciseTimelineBlock>;
        _exercise = exercise;
        if (_sectorFilter != _shared &&
            !exercise.sectors.any((sector) => sector.id == _sectorFilter)) {
          _sectorFilter = _all;
        }
      });
    } on PlanningTimelineUnavailable {
      if (mounted) {
        setState(() => _loadError =
            'Az 5m fal az adatbázis frissítése után lesz elérhető. '
                'A tervezőasztal továbbra is használható.');
      }
    } catch (_) {
      if (mounted)
        setState(() => _loadError = 'Az idővonal betöltése nem sikerült.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _write(
    Future<List<ExerciseTimelineBlock>> Function() change,
  ) async {
    if (!mounted || _saving || _loading) return;
    setState(() {
      _saving = true;
      _writeError = null;
    });
    widget.onSavingChanged?.call(true);
    try {
      final saved = await change();
      if (mounted) setState(() => _blocks = saved);
    } catch (_) {
      if (mounted) {
        setState(() => _writeError =
            'Az idővonal mentése nem sikerült. Frissítsd a nézetet, majd próbáld újra.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onSavingChanged?.call(false);
      }
    }
  }

  List<ExerciseTimelineBlock> _replace(ExerciseTimelineBlock updated) => [
        for (final block in _blocks)
          if (block.id == updated.id) updated else block,
      ];

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mégse')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _addBlock(
      List<ExerciseBubble> available, List<ExerciseSector> sectors) async {
    final starts = <String?, double>{};
    for (final block in _blocks) {
      starts.update(
        block.sectorId,
        (end) => math.max(end, block.planned.end),
        ifAbsent: () => block.planned.end,
      );
    }

    final result = await showDialog<TimelineDialogResult>(
      context: context,
      builder: (_) => PlanningTimelineDialog(
        bubbles: available,
        sectors: sectors,
        startsBySector: starts,
        preferredSector: _sectorFilter == _all ? null : _sectorFilter,
      ),
    );
    if (result == null) return;
    await _write(() async {
      final block = await widget.repository.addTimelineBlock(
        bubble: result.bubble!,
        sectorId: result.sectorId,
        timing: result.timing!,
        notes: result.notes,
      );
      return [..._blocks, block];
    });
  }

  Future<void> _openBlock(ExerciseTimelineBlock block,
      {required bool actual}) async {
    if (_saving) return;
    final exercise = _exercise!;
    final bubbles = exercise.bubbles
        .where((bubble) => bubble.id == block.bubbleId)
        .toList();
    if (bubbles.isEmpty) {
      setState(() => _writeError =
          'A buborék adatai megváltoztak. Frissítsd az idővonalat.');
      return;
    }

    final result = await showDialog<TimelineDialogResult>(
      context: context,
      builder: (_) => PlanningTimelineDialog(
        bubbles: bubbles,
        sectors: exercise.sectors,
        startsBySector: const {},
        block: block,
        actual: actual,
      ),
    );
    if (!mounted || result == null) return;

    switch (result.action) {
      case TimelineDialogAction.save:
        await _write(() async {
          final updated = actual
              ? await widget.repository.updateActualTimeline(
                  block: block,
                  timing: result.timing!,
                  status: result.status,
                )
              : await widget.repository.updatePlannedTimeline(
                  block: block,
                  sectorId: result.sectorId,
                  timing: result.timing!,
                  notes: result.notes,
                );
          return _replace(updated);
        });
      case TimelineDialogAction.copy:
        final overwrite = block.actual != null;
        if (overwrite &&
            !await _confirm(
                'Másolás Real-re',
                'Felülírod a Real kezdését és időtartamát a mentett tervvel?',
                'Felülírás')) {
          return;
        }
        await _write(() async => _replace(
              await widget.repository
                  .copyTimelineToActual(block, overwrite: overwrite),
            ));
      case TimelineDialogAction.delete:
        if (!await _confirm('Idővonalblokk törlése',
            'Törlöd a buborék Tervezett és Real időzítését?', 'Törlés')) {
          return;
        }
        await _write(() async {
          await widget.repository.deleteTimelineBlock(block);
          return _blocks.where((item) => item.id != block.id).toList();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError case final error?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Újrapróbálás')),
            ],
          ),
        ),
      );
    }

    final exercise = _exercise!;
    final bubbles = {for (final bubble in exercise.bubbles) bubble.id: bubble};
    final scheduled = _blocks.map((block) => block.bubbleId).toSet();
    final available = exercise.bubbles
        .where((bubble) => !scheduled.contains(bubble.id))
        .toList();
    final bySector = <String, List<ExerciseTimelineBlock>>{};
    var plannedEnd = 0.0;
    var actualEnd = 0.0;
    var hasActual = false;
    for (final block in _blocks) {
      bySector.putIfAbsent(block.sectorId ?? _shared, () => []).add(block);
      plannedEnd = math.max(plannedEnd, block.planned.end);
      if (block.actual case final actual?) {
        hasActual = true;
        actualEnd = math.max(actualEnd, actual.end);
      }
    }
    final sectors = {
      _shared: 'Közös célok',
      for (final sector in exercise.sectors) sector.id: sector.name,
    };
    final groups = [
      for (final sector in sectors.entries)
        if (_sectorFilter == _all || _sectorFilter == sector.key)
          (
            name: sector.value,
            blocks: bySector[sector.key] ?? <ExerciseTimelineBlock>[]
          ),
    ];
    final visible = groups.expand((group) => group.blocks).toList();
    final horizon =
        math.max(8.0, math.max(plannedEnd, actualEnd).ceilToDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _sectorFilter,
                onChanged: (value) {
                  if (value != null) setState(() => _sectorFilter = value);
                },
                items: [
                  const DropdownMenuItem(
                      value: _all, child: Text('Minden pálya')),
                  for (final sector in sectors.entries)
                    DropdownMenuItem(
                        value: sector.key, child: Text(sector.value)),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _saving || available.isEmpty
                    ? null
                    : () => _addBlock(available, exercise.sectors),
                icon: const Icon(Icons.add),
                label: const Text('Buborék az idővonalra'),
              ),
              PopupMenuButton<({ExerciseTimelineBlock block, bool actual})>(
                tooltip: 'Idővonalblokk megnyitása',
                enabled: !_saving && visible.isNotEmpty,
                onSelected: (entry) =>
                    _openBlock(entry.block, actual: entry.actual),
                itemBuilder: (_) => [
                  for (final block in visible) ...[
                    PopupMenuItem(
                      value: (block: block, actual: false),
                      child: Text(
                          'Tervezett · ${bubbles[block.bubbleId]?.title ?? 'Buborék'}'),
                    ),
                    if (block.actual != null)
                      PopupMenuItem(
                        value: (block: block, actual: true),
                        child: Text(
                            'Real · ${bubbles[block.bubbleId]?.title ?? 'Buborék'}'),
                      ),
                  ],
                ],
                icon: const Icon(Icons.schedule),
              ),
              IconButton(
                tooltip: 'Idővonal frissítése',
                onPressed: _saving ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_saving) const LinearProgressIndicator(),
        if (_writeError case final error?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (exercise.bubbles.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Az idővonalhoz előbb adj hozzá egy buborékot a tervezőasztalon.'),
          )
        else if (_blocks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 16,
              children: [
                Text('Tervezett ENDEX: +${planningHours(plannedEnd)} óra'),
                if (hasActual)
                  Text(
                      'Utolsó Real befejezés: +${planningHours(actualEnd)} óra · '
                      '${formatTimelineVariance(actualEnd - plannedEnd)}'),
              ],
            ),
          ),
        Expanded(
          child: PlanningTimelineCanvas(
            groups: groups,
            bubbles: bubbles,
            horizon: horizon,
            enabled: !_saving,
            onOpen: _openBlock,
          ),
        ),
      ],
    );
  }
}
