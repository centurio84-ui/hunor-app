import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/hunor_theme.dart';
import 'planning_catalog_panel.dart' show planningDragFeedback, planningHours;
import 'planning_models.dart';
import 'planning_repository.dart';

enum _TrackKind {
  goals('CÉLOK', 'Cél', Icons.flag_rounded, Color(0xFF38BDF8)),
  obstacles('AKADÁLYOK', 'Akadály', Icons.construction_rounded, Color(0xFFF59E0B)),
  victims('SÉRÜLTEK', 'Sérült', Icons.medical_services_rounded, Color(0xFFEF4444)),
  injects('INJEKTEK', 'Injekt', Icons.bolt_rounded, Color(0xFFD946EF));

  const _TrackKind(this.label, this.shortLabel, this.icon, this.color);
  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;
}

_TrackKind _trackKindOf(ExerciseBubble bubble) {
  if (bubble.specs['is_obstacle'] == true) return _TrackKind.obstacles;
  if (bubble.discipline == BubbleDiscipline.medical) return _TrackKind.victims;
  if (bubble.specs['is_inject'] == true ||
      bubble.discipline == BubbleDiscipline.ucc ||
      bubble.discipline == BubbleDiscipline.pressVip) {
    return _TrackKind.injects;
  }
  return _TrackKind.goals;
}

Color _bubbleAccentColor(ExerciseBubble bubble) {
  final kind = _trackKindOf(bubble);
  if (kind == _TrackKind.goals) {
    final sec = InsaragSection.byKey(bubble.specs['section']?.toString());
    if (sec != null) return sec.color;
  }
  return kind.color;
}

double _snapQuarterHour(double hours) =>
    math.max(0.0, (hours * 4).round() / 4.0);

class PlanningTimelinePlanner extends StatefulWidget {
  const PlanningTimelinePlanner({
    super.key,
    required this.exerciseId,
    required this.repository,
    this.onSavingChanged,
  });

  final String exerciseId;
  final PlanningRepository repository;
  final ValueChanged<bool>? onSavingChanged;

  @override
  State<PlanningTimelinePlanner> createState() =>
      _PlanningTimelinePlannerState();
}

class _PlanningTimelinePlannerState extends State<PlanningTimelinePlanner> {
  static const _allSectors = '__ALL__';
  static const _unassignedSector = '__NONE__';
  static const _headerWidth = 176.0;
  static const _laneHeight = 46.0;
  static const _sectorBannerHeight = 38.0;

  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _writeError;

  ExerciseDetails? _exercise;
  List<ExerciseTimelineBlock> _blocks = [];

  String _sectorFilter = _allSectors;
  _TrackKind? _paletteKindFilter;
  double _horizonHours = 36.0;
  double _pixelsPerHour = 68.0;

  // Élő csúszka-előnézet húzás közben
  final Map<String, TimelineTiming> _dragOverrides = {};
  // Élő DAW ejtési vonal (melyik sor felett és hányadik óránál tart az egér)
  String? _hoverTrackKey;
  double? _hoverHour;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
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
      final blocks = results[0] as List<ExerciseTimelineBlock>;
      final exercise = results[1] as ExerciseDetails;
      var maxEnd = _horizonHours;
      for (final b in blocks) {
        if (b.planned.end > maxEnd) {
          maxEnd = (b.planned.end / 6).ceil() * 6.0;
        }
      }
      setState(() {
        _blocks = blocks;
        _exercise = exercise;
        _horizonHours = maxEnd;
        if (_sectorFilter != _allSectors &&
            _sectorFilter != _unassignedSector &&
            !exercise.sectors.any((s) => s.id == _sectorFilter)) {
          _sectorFilter = _allSectors;
        }
      });
    } on PlanningTimelineUnavailable {
      if (mounted) {
        setState(() => _loadError =
            'Az idővonal tábla még nem érhető el az adatbázisban.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Az idővonal betöltése nem sikerült.');
      }
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
      if (mounted) {
        setState(() {
          _blocks = saved;
          _dragOverrides.clear();
          _hoverTrackKey = null;
          _hoverHour = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dragOverrides.clear();
          _hoverTrackKey = null;
          _hoverHour = null;
          _writeError =
              'Az idővonal mentése nem sikerült. Frissítsd a nézetet és próbáld újra.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onSavingChanged?.call(false);
      }
    }
  }

  List<ExerciseTimelineBlock> _replace(ExerciseTimelineBlock updated) => [
        for (final b in _blocks)
          if (b.id == updated.id) updated else b,
      ];

  Future<void> _placeBubbleOnTrack(
    ExerciseBubble bubble, {
    required String? sectorId,
    required double startHour,
  }) async {
    final start = _snapQuarterHour(startHour);
    final duration = (bubble.estimatedHours != null && bubble.estimatedHours! > 0)
        ? math.max(0.25, _snapQuarterHour(bubble.estimatedHours!))
        : 1.5;

    await _write(() async {
      final created = await widget.repository.addTimelineBlock(
        bubble: bubble,
        sectorId: sectorId,
        timing: TimelineTiming(start, duration),
        notes: '',
      );
      return [..._blocks, created];
    });
  }

  Future<void> _commitTiming(
    ExerciseTimelineBlock block,
    TimelineTiming timing,
  ) async {
    final snappedStart = _snapQuarterHour(timing.start);
    final snappedDur = math.max(0.25, _snapQuarterHour(timing.duration));
    if ((snappedStart - block.planned.start).abs() < 0.001 &&
        (snappedDur - block.planned.duration).abs() < 0.001) {
      setState(() => _dragOverrides.remove(block.id));
      return;
    }
    await _write(() async {
      final updated = await widget.repository.updatePlannedTimeline(
        block: block,
        sectorId: block.sectorId,
        timing: TimelineTiming(snappedStart, snappedDur),
        notes: block.notes,
      );
      return _replace(updated);
    });
  }

  Future<void> _removeBlock(ExerciseTimelineBlock block) async {
    await _write(() async {
      await widget.repository.deleteTimelineBlock(block);
      return _blocks.where((b) => b.id != block.id).toList();
    });
  }

  Future<void> _editBlockDialog(
    ExerciseTimelineBlock block,
    ExerciseBubble bubble,
  ) async {
    final result = await showDialog<_PlannedBlockEdit>(
      context: context,
      builder: (_) => _PlannedBlockDialog(bubble: bubble, block: block),
    );
    if (!mounted || result == null) return;
    if (result.delete) {
      await _removeBlock(block);
      return;
    }
    await _write(() async {
      final updated = await widget.repository.updatePlannedTimeline(
        block: block,
        sectorId: block.sectorId,
        timing: TimelineTiming(result.start, result.duration),
        notes: result.notes,
      );
      return _replace(updated);
    });
  }

  double get _plannedEndex {
    double maxEnd = 0;
    for (final b in _blocks) {
      final t = _dragOverrides[b.id] ?? b.planned;
      if (t.end > maxEnd) maxEnd = t.end;
    }
    return maxEnd;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError case final error?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Újrapróbálás')),
            ],
          ),
        ),
      );
    }

    final exercise = _exercise!;
    final bubbleMap = {for (final b in exercise.bubbles) b.id: b};
    final scheduledBubbleIds = {for (final blk in _blocks) blk.bubbleId};
    final unscheduled = exercise.bubbles
        .where((b) => !scheduledBubbleIds.contains(b.id))
        .toList();

    final hasUnassigned = exercise.bubbles.any((b) => b.sectorId == null) ||
        _blocks.any((blk) => blk.sectorId == null);

    final groups = <({String? sectorId, String name, String icmsName})>[
      for (final s in exercise.sectors)
        if (_sectorFilter == _allSectors || _sectorFilter == s.id)
          (sectorId: s.id, name: s.name, icmsName: s.icmsName),
      if (hasUnassigned &&
          (_sectorFilter == _allSectors || _sectorFilter == _unassignedSector))
        (sectorId: null, name: 'Közös / pálya nélküli', icmsName: ''),
    ];

    final endex = _plannedEndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saving) const LinearProgressIndicator(),
        if (_writeError case final error?)
          ListTile(
            dense: true,
            leading: const Icon(Icons.error_outline),
            title: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            trailing: IconButton(
              tooltip: 'Bezárás',
              onPressed: () => setState(() => _writeError = null),
              icon: const Icon(Icons.close),
            ),
          ),

        // Felső DAW vezérlősáv
        Material(
          color: HunorColors.surface1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _sectorFilter,
                    decoration: const InputDecoration(
                      labelText: 'Pálya szűrése',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: _allSectors,
                        child: Text('Minden pálya'),
                      ),
                      for (final s in exercise.sectors)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      if (hasUnassigned)
                        const DropdownMenuItem(
                          value: _unassignedSector,
                          child: Text('Közös / pálya nélküli'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _sectorFilter = v);
                    },
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<double>(
                    value: [12.0, 24.0, 36.0, 48.0].contains(_horizonHours)
                        ? _horizonHours
                        : 36.0,
                    decoration: const InputDecoration(
                      labelText: 'Időskála',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 12.0, child: Text('12 óra')),
                      DropdownMenuItem(value: 24.0, child: Text('24 óra')),
                      DropdownMenuItem(value: 36.0, child: Text('36 óra')),
                      DropdownMenuItem(value: 48.0, child: Text('48 óra')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _horizonHours = v);
                    },
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Kicsinyítés',
                      onPressed: _pixelsPerHour <= 36
                          ? null
                          : () => setState(() => _pixelsPerHour =
                              math.max(36, _pixelsPerHour - 12)),
                      icon: const Icon(Icons.zoom_out),
                    ),
                    Text(
                      '${_pixelsPerHour.round()} px/ó',
                      style: const TextStyle(
                        fontSize: 12,
                        color: HunorColors.muted,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Nagyítás',
                      onPressed: _pixelsPerHour >= 140
                          ? null
                          : () => setState(() => _pixelsPerHour =
                              math.min(140, _pixelsPerHour + 12)),
                      icon: const Icon(Icons.zoom_in),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: HunorColors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: HunorColors.gold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    endex > 0
                        ? 'Tervezett ENDEX: +${planningHours(endex)} óra'
                        : 'Tervezett ENDEX: 0 óra',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: HunorColors.gold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Frissítés',
                  onPressed: _saving ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Fő elrendezés: Bal oldali hangminta/elem-tár + Jobb oldali többsávos DAW idővonal
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final leftPalette = _buildUnscheduledPalette(
                exercise: exercise,
                unscheduled: unscheduled,
              );
              final timelineArea = groups.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Még nincs felvett pálya. Hozz létre pályákat az „1. Tervezőasztal & Pályák” fülön, majd húzd be ide az elemeket!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _buildDawTimeline(
                      groups: groups,
                      bubbleMap: bubbleMap,
                    );

              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 290, child: leftPalette),
                    const VerticalDivider(width: 1),
                    Expanded(child: timelineArea),
                  ],
                );
              }
              return Column(
                children: [
                  SizedBox(height: 220, child: leftPalette),
                  const Divider(height: 1),
                  Expanded(child: timelineArea),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnscheduledPalette({
    required ExerciseDetails exercise,
    required List<ExerciseBubble> unscheduled,
  }) {
    final sectorById = {for (final s in exercise.sectors) s.id: s};
    final filtered = unscheduled.where((b) {
      final matchesSector = _sectorFilter == _allSectors ||
          (_sectorFilter == _unassignedSector
              ? b.sectorId == null
              : b.sectorId == _sectorFilter);
      final matchesKind =
          _paletteKindFilter == null || _trackKindOf(b) == _paletteKindFilter;
      return matchesSector && matchesKind;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Behúzható elemek (${filtered.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Húzd rá bármelyik sávra jobbra, vagy nyomd meg a + gombot!',
            style: TextStyle(fontSize: 11.5, color: HunorColors.muted),
          ),
          const SizedBox(height: 8),
          // 4 szekció gyors-szűrő (Célok / Akadályok / Sérültek / Injektek)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Mind', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                selected: _paletteKindFilter == null,
                onSelected: (_) => setState(() => _paletteKindFilter = null),
              ),
              for (final kind in _TrackKind.values)
                ChoiceChip(
                  avatar: Icon(kind.icon, size: 14, color: kind.color),
                  label: Text(kind.shortLabel,
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  selected: _paletteKindFilter == kind,
                  onSelected: (_) => setState(() => _paletteKindFilter =
                      _paletteKindFilter == kind ? null : kind),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Nincs több behúzható elem ebben a szűrésben.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: HunorColors.muted, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    primary: false,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final bubble = filtered[index];
                      final kind = _trackKindOf(bubble);
                      final accent = _bubbleAccentColor(bubble);
                      final sectorName = bubble.sectorId != null
                          ? (sectorById[bubble.sectorId]?.name ?? 'Pálya')
                          : 'Közös';

                      final card = Card(
                        margin: EdgeInsets.zero,
                        color: HunorColors.surface2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: accent.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: accent, width: 5),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 2,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                accent.withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            kind.shortLabel,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          sectorName,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: HunorColors.gold,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      bubble.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Azonnali felhelyezés az idővonalra',
                                visualDensity: VisualDensity.compact,
                                onPressed: _saving
                                    ? null
                                    : () {
                                        final targetSector = bubble.sectorId ??
                                            (exercise.sectors.isNotEmpty
                                                ? exercise.sectors.first.id
                                                : null);
                                        double nextStart = 0;
                                        for (final blk in _blocks) {
                                          if (blk.sectorId == targetSector) {
                                            final b = exercise.bubbles
                                                .where((x) =>
                                                    x.id == blk.bubbleId)
                                                .firstOrNull;
                                            if (b != null &&
                                                _trackKindOf(b) == kind &&
                                                blk.planned.end > nextStart) {
                                              nextStart = blk.planned.end;
                                            }
                                          }
                                        }
                                        _placeBubbleOnTrack(
                                          bubble,
                                          sectorId: targetSector,
                                          startHour: nextStart,
                                        );
                                      },
                                icon: Icon(
                                  Icons.add_circle,
                                  size: 20,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );

                      return Draggable<ExerciseBubble>(
                        data: bubble,
                        maxSimultaneousDrags: _saving ? 0 : 1,
                        feedback: planningDragFeedback(
                          '${kind.shortLabel}: ${bubble.title}',
                          accentColor: accent,
                        ),
                        childWhenDragging: Opacity(opacity: 0.35, child: card),
                        child: card,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// DAW-szerű többsávos elrendezés:
  /// - Bal oldalon RÖGZÍTETT (nem görget el vízszintesen!) sáv-fejlécek (Pálya + 4 külön sáv: CÉLOK, AKADÁLYOK, SÉRÜLTEK, INJEKTEK)
  /// - Jobb oldalon vízszintesen görgethető, 15 perces / órás rácsos idővonal
  Widget _buildDawTimeline({
    required List<({String? sectorId, String name, String icmsName})> groups,
    required Map<String, ExerciseBubble> bubbleMap,
  }) {
    final trackWidth = _horizonHours * _pixelsPerHour + 40;
    final hourStep = _pixelsPerHour < 45 ? 2 : 1;

    // Előre kiszámítjuk minden pálya és minden sáv sávszámát + magasságát, hogy a rögzített bal oszlop és a jobb rács pixelpontosan egyvonalban legyen!
    final layouts = <({
      String? sectorId,
      String name,
      String icmsName,
      int totalCount,
      List<({
        _TrackKind kind,
        double height,
        List<({
          ExerciseTimelineBlock block,
          ExerciseBubble bubble,
          TimelineTiming timing,
          int lane,
        })> placed,
      })> tracks,
    })>[];

    for (final group in groups) {
      final sectorBlocks =
          _blocks.where((b) => b.sectorId == group.sectorId).toList();
      final tracks = <({
        _TrackKind kind,
        double height,
        List<({
          ExerciseTimelineBlock block,
          ExerciseBubble bubble,
          TimelineTiming timing,
          int lane,
        })> placed,
      })>[];

      for (final kind in _TrackKind.values) {
        final kindBlocks = sectorBlocks.where((blk) {
          final b = bubbleMap[blk.bubbleId];
          return b != null && _trackKindOf(b) == kind;
        }).toList()
          ..sort((a, b) {
            final ta = _dragOverrides[a.id] ?? a.planned;
            final tb = _dragOverrides[b.id] ?? b.planned;
            return ta.start.compareTo(tb.start);
          });

        final laneEnds = <double>[];
        final placed = <({
          ExerciseTimelineBlock block,
          ExerciseBubble bubble,
          TimelineTiming timing,
          int lane,
        })>[];
        for (final blk in kindBlocks) {
          final bubble = bubbleMap[blk.bubbleId];
          if (bubble == null) continue;
          final timing = _dragOverrides[blk.id] ?? blk.planned;
          var lane = laneEnds.indexWhere((end) => end <= timing.start + 0.001);
          if (lane < 0) {
            lane = laneEnds.length;
            laneEnds.add(timing.end);
          } else {
            laneEnds[lane] = timing.end;
          }
          placed.add((block: blk, bubble: bubble, timing: timing, lane: lane));
        }
        final laneCount = math.max(1, laneEnds.length);
        tracks.add((
          kind: kind,
          height: laneCount * _laneHeight + 10.0,
          placed: placed,
        ));
      }

      layouts.add((
        sectorId: group.sectorId,
        name: group.name,
        icmsName: group.icmsName,
        totalCount: sectorBlocks.length,
        tracks: tracks,
      ));
    }

    return Scrollbar(
      controller: _vScroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vScroll,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BAL OLDALI RÖGZÍTETT DAW SÁV-FEJLÉC OSZLOP
            SizedBox(
              width: _headerWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bal felső sarok (STARTEX fejléc magassága)
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: const BoxDecoration(
                      color: HunorColors.surface2,
                      border: Border(
                        right: BorderSide(color: HunorColors.border, width: 1.5),
                        bottom: BorderSide(color: HunorColors.border),
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'PÁLYÁK / SÁVOK',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                        color: HunorColors.gold,
                      ),
                    ),
                  ),
                  for (final group in layouts) ...[
                    // Pálya elválasztó fejléc (bal oldal)
                    Container(
                      height: _sectorBannerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16253A),
                        border: const Border(
                          top: BorderSide(color: HunorColors.gold, width: 1.5),
                          right:
                              BorderSide(color: HunorColors.border, width: 1.5),
                          bottom: BorderSide(color: HunorColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (group.icmsName.isNotEmpty)
                            Text(
                              group.icmsName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: HunorColors.gold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // A 4 külön DAW sáv-fejléc (CÉLOK, AKADÁLYOK, SÉRÜLTEK, INJEKTEK)
                    for (final tr in group.tracks)
                      Container(
                        height: tr.height,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: tr.kind.color.withValues(alpha: 0.12),
                          border: Border(
                            left: BorderSide(color: tr.kind.color, width: 5),
                            right: const BorderSide(
                                color: HunorColors.border, width: 1.5),
                            bottom: const BorderSide(
                                color: HunorColors.border, width: 0.8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(tr.kind.icon, size: 16, color: tr.kind.color),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                tr.kind.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                  color: tr.kind.color,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: tr.kind.color.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${tr.placed.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: tr.kind.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),

            // JOBB OLDALI VÍZSZINTESEN GÖRGETHETŐ DAW IDŐVONAL RÁCS
            Expanded(
              child: Scrollbar(
                controller: _hScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: trackWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Felső STARTEX óra-vonalzó
                        Container(
                          height: 36,
                          width: trackWidth,
                          decoration: const BoxDecoration(
                            color: HunorColors.surface2,
                            border: Border(
                              bottom: BorderSide(color: HunorColors.border),
                            ),
                          ),
                          child: Stack(
                            children: [
                              for (var h = 0; h <= _horizonHours; h += hourStep)
                                Positioned(
                                  left: h * _pixelsPerHour + 4,
                                  top: 9,
                                  child: Text(
                                    h == 0 ? 'STARTEX' : '+$h ó',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: h == 0
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: h == 0
                                          ? HunorColors.gold
                                          : HunorColors.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final group in layouts) ...[
                          // Pálya banner jobb oldali folytatása
                          Container(
                            height: _sectorBannerHeight,
                            width: trackWidth,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFF16253A),
                              border: Border(
                                top: BorderSide(
                                    color: HunorColors.gold, width: 1.5),
                                bottom: BorderSide(color: HunorColors.border),
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${group.name} · ${group.totalCount} időzített sáv-elem',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: HunorColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          // A 4 külön DAW sáv (mindegyik külön DragTarget!)
                          for (final tr in group.tracks)
                            _buildDawTrackLane(
                              sectorId: group.sectorId,
                              kind: tr.kind,
                              height: tr.height,
                              placed: tr.placed,
                              trackWidth: trackWidth,
                            ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDawTrackLane({
    required String? sectorId,
    required _TrackKind kind,
    required double height,
    required List<({
      ExerciseTimelineBlock block,
      ExerciseBubble bubble,
      TimelineTiming timing,
      int lane,
    })> placed,
    required double trackWidth,
  }) {
    final trackKey = '${sectorId ?? 'none'}-${kind.name}';
    final isHovering = _hoverTrackKey == trackKey;

    return Builder(
      builder: (laneCtx) => DragTarget<ExerciseBubble>(
        onWillAcceptWithDetails: (details) {
          if (_saving) return false;
          // Bármelyik elem behúzható (a saját sávja színnel kiemelkedik, de soha nem utasítja vissza csendben!)
          return details.data.exerciseId == widget.exerciseId;
        },
        onMove: (details) {
          final box = laneCtx.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.offset);
          final snapped = _snapQuarterHour(math.max(0, local.dx / _pixelsPerHour));
          if (_hoverTrackKey != trackKey || _hoverHour != snapped) {
            setState(() {
              _hoverTrackKey = trackKey;
              _hoverHour = snapped;
            });
          }
        },
        onLeave: (_) {
          if (_hoverTrackKey == trackKey) {
            setState(() {
              _hoverTrackKey = null;
              _hoverHour = null;
            });
          }
        },
        onAcceptWithDetails: (details) {
          final box = laneCtx.findRenderObject() as RenderBox?;
          double startHour = _hoverHour ?? 0;
          if (box != null) {
            final local = box.globalToLocal(details.offset);
            startHour = math.max(0, local.dx / _pixelsPerHour);
          }
          _placeBubbleOnTrack(
            details.data,
            sectorId: sectorId,
            startHour: startHour,
          );
        },
        builder: (context, candidates, rejected) {
          final active = candidates.isNotEmpty;
          return Container(
            width: trackWidth,
            height: height,
            decoration: BoxDecoration(
              color: active
                  ? kind.color.withValues(alpha: 0.18)
                  : kind.color.withValues(alpha: 0.04),
              border: const Border(
                bottom: BorderSide(color: HunorColors.border, width: 0.8),
              ),
            ),
            child: Stack(
              children: [
                // Függőleges DAW óra- és 6 órás ütem-rács
                for (var h = 0; h <= _horizonHours; h++)
                  Positioned(
                    left: h * _pixelsPerHour,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: h % 6 == 0 ? 1.4 : 0.6,
                      color: h % 6 == 0
                          ? HunorColors.border
                          : HunorColors.border.withValues(alpha: 0.35),
                    ),
                  ),

                // Élő DAW ejtési vonal (playhead) behúzás közben
                if (isHovering && _hoverHour != null)
                  Positioned(
                    left: _hoverHour! * _pixelsPerHour,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2.5,
                      color: HunorColors.gold,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          margin: const EdgeInsets.only(left: 4, top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: HunorColors.gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${planningHours(_hoverHour!)} ó',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (placed.isEmpty && !active)
                  Positioned(
                    left: 12,
                    top: 16,
                    child: Text(
                      'Húzz ide egy „${kind.shortLabel}” elemet balról…',
                      style: TextStyle(
                        fontSize: 11,
                        color: HunorColors.muted.withValues(alpha: 0.55),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Felhelyezett DAW csúszka-klipek
                for (final item in placed)
                  _buildDawClip(
                    block: item.block,
                    bubble: item.bubble,
                    timing: item.timing,
                    lane: item.lane,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDawClip({
    required ExerciseTimelineBlock block,
    required ExerciseBubble bubble,
    required TimelineTiming timing,
    required int lane,
  }) {
    final accent = _bubbleAccentColor(bubble);
    final leftPx = timing.start * _pixelsPerHour;
    final widthPx = math.max(64.0, timing.duration * _pixelsPerHour);
    final dispStart = _snapQuarterHour(timing.start);
    final dispEnd = _snapQuarterHour(timing.end);
    final dispDur = math.max(0.25, _snapQuarterHour(timing.duration));

    return Positioned(
      left: leftPx,
      top: 5.0 + lane * _laneHeight,
      width: widthPx,
      height: _laneHeight - 6,
      child: Material(
        color: accent.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(7),
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: accent, width: 1.6),
          ),
          child: Row(
            children: [
              // Bal fogantyú (kezdés húzása)
              MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: _saving
                      ? null
                      : (d) {
                          final current =
                              _dragOverrides[block.id] ?? block.planned;
                          final deltaH = d.delta.dx / _pixelsPerHour;
                          final newStart = math.max(
                            0.0,
                            math.min(current.end - 0.25, current.start + deltaH),
                          );
                          setState(() {
                            _dragOverrides[block.id] =
                                TimelineTiming(newStart, current.end - newStart);
                          });
                        },
                  onHorizontalDragEnd: _saving
                      ? null
                      : (_) {
                          final t = _dragOverrides[block.id];
                          if (t != null) _commitTiming(block, t);
                        },
                  child: Container(
                    width: 10,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.65),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(5),
                      ),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 2,
                        height: 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Középső klip-test: vízszintes csúsztatás + kattintásra szerkesztés
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        _saving ? null : () => _editBlockDialog(block, bubble),
                    onHorizontalDragUpdate: _saving
                        ? null
                        : (d) {
                            final current =
                                _dragOverrides[block.id] ?? block.planned;
                            final deltaH = d.delta.dx / _pixelsPerHour;
                            final newStart =
                                math.max(0.0, current.start + deltaH);
                            setState(() {
                              _dragOverrides[block.id] =
                                  TimelineTiming(newStart, current.duration);
                            });
                          },
                    onHorizontalDragEnd: _saving
                        ? null
                        : (_) {
                            final t = _dragOverrides[block.id];
                            if (t != null) _commitTiming(block, t);
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Tooltip(
                        message:
                            '${bubble.title}\n+${planningHours(dispStart)} ó → +${planningHours(dispEnd)} ó (${planningHours(dispDur)} óra)\nHúzd a mozgatáshoz, szélein nyújtsd, kattints a szerkesztéshez.',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bubble.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '+${planningHours(dispStart)}ó – +${planningHours(dispEnd)}ó (${planningHours(dispDur)}ó)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Jobb fogantyú (hossz nyújtása / rövidítése)
              MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: _saving
                      ? null
                      : (d) {
                          final current =
                              _dragOverrides[block.id] ?? block.planned;
                          final deltaH = d.delta.dx / _pixelsPerHour;
                          final newDur =
                              math.max(0.25, current.duration + deltaH);
                          setState(() {
                            _dragOverrides[block.id] =
                                TimelineTiming(current.start, newDur);
                          });
                        },
                  onHorizontalDragEnd: _saving
                      ? null
                      : (_) {
                          final t = _dragOverrides[block.id];
                          if (t != null) _commitTiming(block, t);
                        },
                  child: Container(
                    width: 10,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.65),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(5),
                      ),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 2,
                        height: 14,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannedBlockEdit {
  const _PlannedBlockEdit({
    required this.start,
    required this.duration,
    required this.notes,
    this.delete = false,
  });

  final double start;
  final double duration;
  final String notes;
  final bool delete;
}

class _PlannedBlockDialog extends StatefulWidget {
  const _PlannedBlockDialog({
    required this.bubble,
    required this.block,
  });

  final ExerciseBubble bubble;
  final ExerciseTimelineBlock block;

  @override
  State<_PlannedBlockDialog> createState() => _PlannedBlockDialogState();
}

class _PlannedBlockDialogState extends State<_PlannedBlockDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _start;
  late final TextEditingController _duration;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(
      text: planningHours(widget.block.planned.start),
    );
    _duration = TextEditingController(
      text: planningHours(widget.block.planned.duration),
    );
    _notes = TextEditingController(text: widget.block.notes);
  }

  @override
  void dispose() {
    _start.dispose();
    _duration.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? _parseNum(String? raw) =>
      double.tryParse((raw ?? '').trim().replaceAll(',', '.'));

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _PlannedBlockEdit(
        start: _parseNum(_start.text)!,
        duration: _parseNum(_duration.text)!,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.bubble.title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _start,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Kezdés (STARTEX + óra)',
                      ),
                      validator: (v) {
                        final n = _parseNum(v);
                        if (n == null || n < 0) return 'Min. 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _duration,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Időtartam (óra)',
                      ),
                      validator: (v) {
                        final n = _parseNum(v);
                        if (n == null || n <= 0) return 'Pozitív szám';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Idővonali megjegyzés',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const _PlannedBlockEdit(
              start: 0,
              duration: 1,
              notes: '',
              delete: true,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Levétel az idővonalról'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Mentés'),
        ),
      ],
    );
  }
}
