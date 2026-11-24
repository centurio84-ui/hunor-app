import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/hunor_theme.dart';
import 'planning_catalog_panel.dart' show planningHours;
import 'planning_models.dart';
import 'planning_repository.dart';

enum _RealTrackKind {
  goals('CÉLOK', Icons.flag_rounded, Color(0xFF38BDF8)),
  obstacles('AKADÁLYOK', Icons.construction_rounded, Color(0xFFF59E0B)),
  victims('SÉRÜLTEK', Icons.medical_services_rounded, Color(0xFFEF4444)),
  injects('INJEKTEK', Icons.bolt_rounded, Color(0xFFD946EF));

  const _RealTrackKind(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

_RealTrackKind _realKindOf(ExerciseBubble bubble) {
  if (bubble.specs['is_obstacle'] == true) return _RealTrackKind.obstacles;
  if (bubble.discipline == BubbleDiscipline.medical) return _RealTrackKind.victims;
  if (bubble.specs['is_inject'] == true ||
      bubble.discipline == BubbleDiscipline.ucc ||
      bubble.discipline == BubbleDiscipline.pressVip) {
    return _RealTrackKind.injects;
  }
  return _RealTrackKind.goals;
}

/// Valós idővonal 3 színkódolt státusza (+ alap tervezett állapot):
/// - Sárga: Előkészületben (inProgress)
/// - Zöld: Előkészítve (delayed — meglévő DB enum kulcs újrahasznosítva migráció nélkül)
/// - Piros: Végrehajtva (completed)
({String label, Color color, Color textColor}) _realStatusStyle(
  TimelineStatus status,
) =>
    switch (status) {
      TimelineStatus.inProgress => (
          label: 'Előkészületben',
          color: const Color(0xFFEAB308), // Sárga
          textColor: Colors.black,
        ),
      TimelineStatus.delayed => (
          label: 'Előkészítve',
          color: const Color(0xFF22C55E), // Zöld
          textColor: Colors.black,
        ),
      TimelineStatus.completed => (
          label: 'Végrehajtva',
          color: const Color(0xFFEF4444), // Piros
          textColor: Colors.white,
        ),
      TimelineStatus.planned => (
          label: 'Nincs színezve',
          color: const Color(0xFF64748B), // Semleges szürke-kék
          textColor: Colors.white,
        ),
    };

double _snapQuarter(double hours) => math.max(0.0, (hours * 4).round() / 4.0);

class PlanningRealTimeline extends StatefulWidget {
  const PlanningRealTimeline({
    super.key,
    required this.exerciseId,
    required this.repository,
    this.onSavingChanged,
  });

  final String exerciseId;
  final PlanningRepository repository;
  final ValueChanged<bool>? onSavingChanged;

  @override
  State<PlanningRealTimeline> createState() => _PlanningRealTimelineState();
}

class _PlanningRealTimelineState extends State<PlanningRealTimeline> {
  static const _unassignedKey = '__NONE__';
  static const _headerWidth = 176.0;
  static const _laneHeight = 46.0;
  static const _sectionBannerHeight = 36.0;

  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _writeError;

  ExerciseDetails? _exercise;
  List<ExerciseTimelineBlock> _blocks = [];
  String? _selectedSectorKey;

  double _horizonHours = 36.0;
  double _pixelsPerHour = 68.0;
  late DateTime _startexTime = _defaultStartex();

  final Map<String, TimelineTiming> _dragOverrides = {};

  static DateTime _defaultStartex() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 8, 0);
  }

  String get _startexPrefKey => 'planning_startex_${widget.exerciseId}';

  String _pad2(int n) => n.toString().padLeft(2, '0');

  DateTime _realTimeAt(double offsetHours) =>
      _startexTime.add(Duration(minutes: (offsetHours * 60).round()));

  String _formatClock(double offsetHours, {bool showDateIfNewDay = false}) {
    final dt = _realTimeAt(offsetHours);
    final hhmm = '${_pad2(dt.hour)}:${_pad2(dt.minute)}';
    if (showDateIfNewDay &&
        (dt.day != _startexTime.day ||
            dt.month != _startexTime.month ||
            dt.year != _startexTime.year) &&
        dt.hour == 0 &&
        dt.minute == 0) {
      return '${_pad2(dt.month)}.${_pad2(dt.day)}. $hhmm';
    }
    return hhmm;
  }

  String _formatShortDateTime(double offsetHours) {
    final dt = _realTimeAt(offsetHours);
    return '${_pad2(dt.month)}.${_pad2(dt.day)}. ${_pad2(dt.hour)}:${_pad2(dt.minute)}';
  }

  Future<void> _loadSavedStartex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_startexPrefKey);
      if (raw != null) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null && mounted) {
          setState(() => _startexTime = parsed);
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadSavedStartex();
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
        if (b.planned.end > maxEnd) maxEnd = (b.planned.end / 6).ceil() * 6.0;
        if (b.actual != null && b.actual!.end > maxEnd) {
          maxEnd = (b.actual!.end / 6).ceil() * 6.0;
        }
      }
      String? nextSelected = _selectedSectorKey;
      final validIds = {for (final s in exercise.sectors) s.id};
      final hasUnassigned = blocks.any((b) => b.sectorId == null);
      if (nextSelected == null ||
          (nextSelected != _unassignedKey && !validIds.contains(nextSelected)) ||
          (nextSelected == _unassignedKey && !hasUnassigned)) {
        if (exercise.sectors.isNotEmpty) {
          nextSelected = exercise.sectors.first.id;
        } else if (hasUnassigned) {
          nextSelected = _unassignedKey;
        } else {
          nextSelected = null;
        }
      }
      setState(() {
        _blocks = blocks;
        _exercise = exercise;
        _selectedSectorKey = nextSelected;
        _horizonHours = maxEnd;
      });
    } on PlanningTimelineUnavailable {
      if (mounted) {
        setState(() => _loadError =
            'Az idővonal tábla még nem érhető el az adatbázisban.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'A valós idővonal betöltése nem sikerült.');
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
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dragOverrides.clear();
          _writeError =
              'A valós idővonal mentése nem sikerült. Frissítsd a nézetet és próbáld újra.';
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

  Future<ExerciseTimelineBlock> _ensureCopiedToActual(
    ExerciseTimelineBlock block,
  ) async {
    if (block.actual != null) return block;
    return widget.repository.copyTimelineToActual(block, overwrite: false);
  }

  Future<void> _mirrorAllToReal(List<ExerciseTimelineBlock> sectorBlocks) async {
    final uncopied = sectorBlocks.where((b) => b.actual == null).toList();
    if (uncopied.isEmpty) return;
    await _write(() async {
      var list = [..._blocks];
      for (final blk in uncopied) {
        final copied =
            await widget.repository.copyTimelineToActual(blk, overwrite: false);
        list = [
          for (final item in list)
            if (item.id == copied.id) copied else item,
        ];
      }
      return list;
    });
  }

  Future<void> _commitRealUpdate(
    ExerciseTimelineBlock block, {
    TimelineTiming? timing,
    TimelineStatus? status,
  }) async {
    final targetTiming = timing ?? block.actual ?? block.planned;
    final snappedStart = _snapQuarter(targetTiming.start);
    final snappedDur = math.max(0.25, _snapQuarter(targetTiming.duration));
    final targetStatus = status ?? block.status;

    await _write(() async {
      final copied = await _ensureCopiedToActual(block);
      final updated = await widget.repository.updateActualTimeline(
        block: copied,
        timing: TimelineTiming(snappedStart, snappedDur),
        status: targetStatus,
      );
      return _replace(updated);
    });
  }

  Future<void> _openRealBlockDialog(
    ExerciseTimelineBlock block,
    ExerciseBubble bubble,
  ) async {
    final result = await showDialog<_RealBlockEdit>(
      context: context,
      builder: (_) => _RealBlockDialog(bubble: bubble, block: block),
    );
    if (!mounted || result == null) return;
    await _commitRealUpdate(
      block,
      timing: TimelineTiming(result.start, result.duration),
      status: result.status,
    );
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
    final hasUnassigned = _blocks.any((b) => b.sectorId == null);

    final selectedSectorId =
        _selectedSectorKey == _unassignedKey ? null : _selectedSectorKey;
    final selectedSector = selectedSectorId == null
        ? null
        : exercise.sectors.where((s) => s.id == selectedSectorId).firstOrNull;
    final sectorBlocks =
        _blocks.where((b) => b.sectorId == selectedSectorId).toList();

    final plannedEndex = sectorBlocks.fold<double>(
      0,
      (m, b) => math.max(m, b.planned.end),
    );
    final realEndex = sectorBlocks.fold<double>(
      0,
      (m, b) => math.max(m, (_dragOverrides[b.id] ?? b.actual ?? b.planned).end),
    );
    final uncopiedCount = sectorBlocks.where((b) => b.actual == null).length;

    final prepCount =
        sectorBlocks.where((b) => b.status == TimelineStatus.inProgress).length;
    final readyCount =
        sectorBlocks.where((b) => b.status == TimelineStatus.delayed).length;
    final doneCount =
        sectorBlocks.where((b) => b.status == TimelineStatus.completed).length;

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

        // Felső vezérlősáv: Pálya választó (külön-külön) + Tükrözés + Zoom + Jelmagyarázat
        Material(
          color: HunorColors.surface1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedSectorKey,
                        decoration: const InputDecoration(
                          labelText: 'Kiválasztott pálya',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          for (final s in exercise.sectors)
                            DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                s.icmsName.isNotEmpty
                                    ? '${s.name} (${s.icmsName})'
                                    : s.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (hasUnassigned)
                            const DropdownMenuItem(
                              value: _unassignedKey,
                              child: Text('Közös / pálya nélküli'),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedSectorKey = v);
                          }
                        },
                      ),
                    ),
                    if (uncopiedCount > 0)
                      FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _mirrorAllToReal(sectorBlocks),
                        icon: const Icon(Icons.content_copy_rounded, size: 17),
                        label: Text(
                          'Tervezett tükrözése Valósra ($uncopiedCount)',
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
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: HunorColors.gold.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: HunorColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        'Tervezett: ${_formatShortDateTime(plannedEndex)}  |  Valós: ${_formatShortDateTime(realEndex)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: HunorColors.gold,
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
                const SizedBox(height: 8),
                // Státusz szín-jelmagyarázat és élő számláló
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Valós státusz színek (kattints bármelyik alsó klipre a színezéshez):',
                      style: TextStyle(fontSize: 11.5, color: HunorColors.muted),
                    ),
                    _statusLegendPill(
                      const Color(0xFFEAB308),
                      'Előkészületben: $prepCount',
                    ),
                    _statusLegendPill(
                      const Color(0xFF22C55E),
                      'Előkészítve: $readyCount',
                    ),
                    _statusLegendPill(
                      const Color(0xFFEF4444),
                      'Végrehajtva: $doneCount',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Tükrözött felső (TERVEZETT) + alsó (VALÓS) DAW idővonal
        Expanded(
          child: _selectedSectorKey == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Még nincs felvett pálya. Hozz létre pályákat és tervezz elemeket az „5. Idővonal tervezés” fülön!',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : sectorBlocks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'A(z) „${selectedSector?.name ?? 'Közös'}” pályán még nincs tervezett elem az idővonalon. Húzz be elemeket az „5. Idővonal tervezés” fülön!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _buildMirroredTimeline(
                      sectorName: selectedSector?.name ?? 'Közös / pálya nélküli',
                      sectorBlocks: sectorBlocks,
                      bubbleMap: bubbleMap,
                    ),
        ),
      ],
    );
  }

  Widget _statusLegendPill(Color color, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );

  Widget _buildMirroredTimeline({
    required String sectorName,
    required List<ExerciseTimelineBlock> sectorBlocks,
    required Map<String, ExerciseBubble> bubbleMap,
  }) {
    final trackWidth = _horizonHours * _pixelsPerHour + 40;
    final hourStep = _pixelsPerHour < 45 ? 2 : 1;

    List<({
      _RealTrackKind kind,
      double height,
      List<({
        ExerciseTimelineBlock block,
        ExerciseBubble bubble,
        TimelineTiming timing,
        int lane,
      })> placed,
    })> computeTracks({required bool isReal}) {
      final result = <({
        _RealTrackKind kind,
        double height,
        List<({
          ExerciseTimelineBlock block,
          ExerciseBubble bubble,
          TimelineTiming timing,
          int lane,
        })> placed,
      })>[];

      for (final kind in _RealTrackKind.values) {
        final kindBlocks = sectorBlocks.where((blk) {
          final b = bubbleMap[blk.bubbleId];
          return b != null && _realKindOf(b) == kind;
        }).toList()
          ..sort((a, b) {
            final ta = isReal
                ? (_dragOverrides[a.id] ?? a.actual ?? a.planned)
                : a.planned;
            final tb = isReal
                ? (_dragOverrides[b.id] ?? b.actual ?? b.planned)
                : b.planned;
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
          final timing = isReal
              ? (_dragOverrides[blk.id] ?? blk.actual ?? blk.planned)
              : blk.planned;
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
        result.add((
          kind: kind,
          height: laneCount * _laneHeight + 10.0,
          placed: placed,
        ));
      }
      return result;
    }

    final plannedTracks = computeTracks(isReal: false);
    final realTracks = computeTracks(isReal: true);

    return Scrollbar(
      controller: _vScroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vScroll,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BAL OLDALI RÖGZÍTETT SÁV-FEJLÉCEK (TERVEZETT + VALÓS)
            SizedBox(
              width: _headerWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: const BoxDecoration(
                      color: HunorColors.surface2,
                      border: Border(
                        right: BorderSide(color: HunorColors.border, width: 1.5),
                        bottom: BorderSide(color: HunorColors.border),
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      sectorName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: HunorColors.gold,
                      ),
                    ),
                  ),
                  // TERVEZETT banner (bal)
                  _leftSectionBanner(
                    '📋 TERVEZETT (Felső)',
                    const Color(0xFF0F2942),
                    const Color(0xFF38BDF8),
                  ),
                  for (final tr in plannedTracks) _leftTrackHeader(tr.kind, tr.height, tr.placed.length),
                  const SizedBox(height: 14),
                  // VALÓS banner (bal)
                  _leftSectionBanner(
                    '🔴 VALÓS (Tükrözött)',
                    const Color(0xFF2B1820),
                    const Color(0xFFEF4444),
                  ),
                  for (final tr in realTracks) _leftTrackHeader(tr.kind, tr.height, tr.placed.length),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // JOBB OLDALI SZINKRONIZÁLT IDŐVONAL (TERVEZETT FELÜL + VALÓS ALUL)
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
                        // Közös kétsoros STARTEX + valós óra vonalzó
                        Container(
                          height: 46,
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
                                  top: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        h == 0 ? 'STARTEX' : '+$h ó',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: h == 0
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                          color: h == 0
                                              ? HunorColors.gold
                                              : HunorColors.muted,
                                        ),
                                      ),
                                      Text(
                                        _formatClock(
                                          h.toDouble(),
                                          showDateIfNewDay: true,
                                        ),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: _realTimeAt(h.toDouble())
                                                      .hour ==
                                                  0
                                              ? const Color(0xFF38BDF8)
                                              : Colors.white
                                                  .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // FELSŐ: TERVEZETT IDŐVONAL (csak olvasás referencia)
                        _rightSectionBanner(
                          'TERVEZETT IDŐVONAL – $sectorName (Referencia, nem módosul a valós eltoláskor)',
                          const Color(0xFF0F2942),
                          const Color(0xFF38BDF8),
                          trackWidth,
                        ),
                        for (final tr in plannedTracks)
                          _buildTrackGrid(
                            kind: tr.kind,
                            height: tr.height,
                            placed: tr.placed,
                            trackWidth: trackWidth,
                            isReal: false,
                          ),

                        const SizedBox(height: 14),

                        // ALSÓ: VALÓS IDŐVONAL (tükrözött, csúsztatható + 3 színre színezhető!)
                        _rightSectionBanner(
                          'VALÓS IDŐVONAL – $sectorName (Csúsztatható & színezhető: 🟡 Előkészületben · 🟢 Előkészítve · 🔴 Végrehajtva)',
                          const Color(0xFF2B1820),
                          const Color(0xFFEF4444),
                          trackWidth,
                        ),
                        for (final tr in realTracks)
                          _buildTrackGrid(
                            kind: tr.kind,
                            height: tr.height,
                            placed: tr.placed,
                            trackWidth: trackWidth,
                            isReal: true,
                          ),
                        const SizedBox(height: 24),
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

  Widget _leftSectionBanner(String text, Color bg, Color accent) => Container(
        height: _sectionBannerHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(color: accent, width: 2),
            right: const BorderSide(color: HunorColors.border, width: 1.5),
            bottom: const BorderSide(color: HunorColors.border),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: accent,
          ),
        ),
      );

  Widget _rightSectionBanner(
    String text,
    Color bg,
    Color accent,
    double width,
  ) =>
      Container(
        height: _sectionBannerHeight,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(color: accent, width: 2),
            bottom: const BorderSide(color: HunorColors.border),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
      );

  Widget _leftTrackHeader(_RealTrackKind kind, double height, int count) =>
      Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: kind.color.withValues(alpha: 0.1),
          border: Border(
            left: BorderSide(color: kind.color, width: 5),
            right: const BorderSide(color: HunorColors.border, width: 1.5),
            bottom: const BorderSide(color: HunorColors.border, width: 0.8),
          ),
        ),
        child: Row(
          children: [
            Icon(kind.icon, size: 15, color: kind.color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                kind.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: kind.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: kind.color,
              ),
            ),
          ],
        ),
      );

  Widget _buildTrackGrid({
    required _RealTrackKind kind,
    required double height,
    required List<({
      ExerciseTimelineBlock block,
      ExerciseBubble bubble,
      TimelineTiming timing,
      int lane,
    })> placed,
    required double trackWidth,
    required bool isReal,
  }) {
    return Container(
      width: trackWidth,
      height: height,
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: isReal ? 0.05 : 0.03),
        border: const Border(
          bottom: BorderSide(color: HunorColors.border, width: 0.8),
        ),
      ),
      child: Stack(
        children: [
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
          for (final item in placed)
            isReal
                ? _buildRealClip(
                    block: item.block,
                    bubble: item.bubble,
                    timing: item.timing,
                    lane: item.lane,
                  )
                : _buildPlannedRefClip(
                    bubble: item.bubble,
                    kind: kind,
                    timing: item.timing,
                    lane: item.lane,
                  ),
        ],
      ),
    );
  }

  Widget _buildPlannedRefClip({
    required ExerciseBubble bubble,
    required _RealTrackKind kind,
    required TimelineTiming timing,
    required int lane,
  }) {
    final accent = kind.color;
    final leftPx = timing.start * _pixelsPerHour;
    final widthPx = math.max(64.0, timing.duration * _pixelsPerHour);

    return Positioned(
      left: leftPx,
      top: 5.0 + lane * _laneHeight,
      width: widthPx,
      height: _laneHeight - 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.2),
        ),
        child: Tooltip(
          message:
              'TERVEZETT: ${bubble.title}\n${_formatClock(timing.start)}–${_formatClock(timing.end)} (+${planningHours(timing.start)}ó · ${planningHours(timing.duration)}ó)',
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
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                '${_formatClock(timing.start)}–${_formatClock(timing.end)} (${planningHours(timing.duration)}ó)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealClip({
    required ExerciseTimelineBlock block,
    required ExerciseBubble bubble,
    required TimelineTiming timing,
    required int lane,
  }) {
    final style = _realStatusStyle(block.status);
    final leftPx = timing.start * _pixelsPerHour;
    final widthPx = math.max(96.0, timing.duration * _pixelsPerHour);
    final dispStart = _snapQuarter(timing.start);
    final dispEnd = _snapQuarter(timing.end);

    return Positioned(
      left: leftPx,
      top: 5.0 + lane * _laneHeight,
      width: widthPx,
      height: _laneHeight - 6,
      child: Material(
        color: style.color.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(7),
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.4),
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
                          final current = _dragOverrides[block.id] ??
                              block.actual ??
                              block.planned;
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
                          if (t != null) _commitRealUpdate(block, timing: t);
                        },
                  child: Container(
                    width: 9,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),

              // Középső rész: csúsztatás + kattintásra színezés / időzítés
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _saving
                        ? null
                        : () => _openRealBlockDialog(block, bubble),
                    onHorizontalDragUpdate: _saving
                        ? null
                        : (d) {
                            final current = _dragOverrides[block.id] ??
                                block.actual ??
                                block.planned;
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
                            if (t != null) _commitRealUpdate(block, timing: t);
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Tooltip(
                        message:
                            'VALÓS: ${bubble.title}\nStátusz: ${style.label}\n${_formatClock(dispStart)}–${_formatClock(dispEnd)}\nKattints a színezéshez (🟡 Sárga / 🟢 Zöld / 🔴 Piros) vagy húzd az idővonalon!',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bubble.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: style.textColor,
                              ),
                            ),
                            Text(
                              '${style.label} · ${_formatClock(dispStart)}–${_formatClock(dispEnd)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: style.textColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Jobb fogantyú (időtartam nyújtása / rövidítése)
              MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: _saving
                      ? null
                      : (d) {
                          final current = _dragOverrides[block.id] ??
                              block.actual ??
                              block.planned;
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
                          if (t != null) _commitRealUpdate(block, timing: t);
                        },
                  child: Container(
                    width: 9,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(5),
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

class _RealBlockEdit {
  const _RealBlockEdit({
    required this.start,
    required this.duration,
    required this.status,
  });

  final double start;
  final double duration;
  final TimelineStatus status;
}

class _RealBlockDialog extends StatefulWidget {
  const _RealBlockDialog({required this.bubble, required this.block});

  final ExerciseBubble bubble;
  final ExerciseTimelineBlock block;

  @override
  State<_RealBlockDialog> createState() => _RealBlockDialogState();
}

class _RealBlockDialogState extends State<_RealBlockDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _start;
  late final TextEditingController _duration;
  late TimelineStatus _status;

  @override
  void initState() {
    super.initState();
    final t = widget.block.actual ?? widget.block.planned;
    _start = TextEditingController(text: planningHours(t.start));
    _duration = TextEditingController(text: planningHours(t.duration));
    _status = widget.block.status;
  }

  @override
  void dispose() {
    _start.dispose();
    _duration.dispose();
    super.dispose();
  }

  double? _parseNum(String? raw) =>
      double.tryParse((raw ?? '').trim().replaceAll(',', '.'));

  void _submit([TimelineStatus? quickStatus]) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _RealBlockEdit(
        start: _parseNum(_start.text)!,
        duration: _parseNum(_duration.text)!,
        status: quickStatus ?? _status,
      ),
    );
  }

  Widget _colorStatusButton(TimelineStatus status) {
    final st = _realStatusStyle(status);
    final selected = _status == status;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _status = status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? st.color : st.color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: st.color,
              width: selected ? 2.5 : 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? st.textColor : st.color,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                st.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: selected ? st.textColor : st.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.bubble.title),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Valós állapot / színezés:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _colorStatusButton(TimelineStatus.inProgress), // Sárga
                  const SizedBox(width: 8),
                  _colorStatusButton(TimelineStatus.delayed), // Zöld
                  const SizedBox(width: 8),
                  _colorStatusButton(TimelineStatus.completed), // Piros
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _start,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valós kezdés (+óra)',
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
                        labelText: 'Valós időtartam (óra)',
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
            ],
          ),
        ),
      ),
      actions: [
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
