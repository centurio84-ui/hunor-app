import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/hunor_theme.dart';
import 'planning_catalog_panel.dart' show planningHours;
import 'planning_discipline_badge.dart';
import 'planning_models.dart';

typedef TimelineGroup = ({String name, List<ExerciseTimelineBlock> blocks});

class PlanningTimelineCanvas extends StatefulWidget {
  const PlanningTimelineCanvas({
    super.key,
    required this.groups,
    required this.bubbles,
    required this.horizon,
    required this.enabled,
    required this.onOpen,
  });

  final List<TimelineGroup> groups;
  final Map<String, ExerciseBubble> bubbles;
  final double horizon;
  final bool enabled;
  final void Function(ExerciseTimelineBlock, {required bool actual}) onOpen;

  @override
  State<PlanningTimelineCanvas> createState() => _PlanningTimelineCanvasState();
}

class _PlanningTimelineCanvasState extends State<PlanningTimelineCanvas> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  static const _labelWidth = 102.0;
  static const _rowHeight = 44.0;

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final step = math.max(1.0, (widget.horizon / 12).ceilToDouble());
        final ticks = (widget.horizon / step).ceil();
        final width = math.max(
          constraints.maxWidth - _labelWidth - 32,
          math.min(12000.0, widget.horizon * 68),
        );
        double offset(double hour) => hour / widget.horizon * width;

        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _labelWidth + width + 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: _labelWidth),
                    child: SizedBox(
                      width: width + 32,
                      height: 30,
                      child: Stack(
                        children: [
                          for (var tick = 0; tick <= ticks; tick++)
                            if (tick * step <= widget.horizon)
                              Positioned(
                                left: offset(tick * step),
                                child: Text(
                                  tick == 0
                                      ? 'STARTEX'
                                      : '+${planningHours(tick * step)} ó',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _vertical,
                      child: ListView.builder(
                        controller: _vertical,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: widget.groups.length,
                        itemBuilder: (_, index) {
                          final group = widget.groups[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: HunorColors.surface1,
                                border: Border.all(color: HunorColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(group.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                  ),
                                  _track(group.blocks, width, step, offset,
                                      actual: false),
                                  _track(group.blocks, width, step, offset,
                                      actual: true),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _track(
    List<ExerciseTimelineBlock> blocks,
    double width,
    double step,
    double Function(double) offset, {
    required bool actual,
  }) {
    final entries = [
      for (final block in blocks)
        if (!actual || block.actual != null)
          (block: block, timing: actual ? block.actual! : block.planned),
    ]..sort((a, b) => a.timing.start.compareTo(b.timing.start));

    final laneEnds = <double>[];
    final bars = <Widget>[];
    for (final entry in entries) {
      var lane = laneEnds.indexWhere((end) => end <= entry.timing.start);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(entry.timing.end);
      } else {
        laneEnds[lane] = entry.timing.end;
      }

      bars.add(Positioned(
        left: offset(entry.timing.start),
        top: lane * _rowHeight + 4,
        width: math.max(2, offset(entry.timing.duration)),
        height: _rowHeight - 8,
        child: _bar(entry.block, entry.timing, actual: actual),
      ));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _labelWidth - 1,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(actual ? 'Real' : 'Tervezett'),
          ),
        ),
        Container(
          width: width + 20,
          height: math.max(1, laneEnds.length) * _rowHeight,
          color: actual ? HunorColors.surface2 : HunorColors.surface1,
          child: Stack(
            children: [
              for (var hour = 0.0; hour <= widget.horizon; hour += step)
                Positioned(
                  left: offset(hour),
                  top: 0,
                  bottom: 0,
                  child: const VerticalDivider(
                      width: 1, color: HunorColors.border),
                ),
              if (entries.isEmpty)
                Center(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(actual
                          ? 'Nincs Real blokk'
                          : 'Nincs tervezett blokk'),
                    ),
                  ),
                ),
              ...bars,
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(
    ExerciseTimelineBlock block,
    TimelineTiming timing, {
    required bool actual,
  }) {
    final bubble = widget.bubbles[block.bubbleId];
    final title = bubble?.title ?? 'Buborék';
    final color =
        planningDisciplineColor(bubble?.discipline ?? BubbleDiscipline.custom);
    final variance = block.endVariance;
    final details = [
      title,
      '${planningHours(timing.start)}–${planningHours(timing.end)} óra',
      if (actual) block.status.label,
      if (actual && variance != null)
        'Eltérés a tervezett befejezéstől · ${formatTimelineVariance(variance)}',
      if (block.notes.isNotEmpty) block.notes,
    ].join('\n');

    return Tooltip(
      message: details,
      child: Semantics(
        label: '${actual ? 'Real' : 'Tervezett'} · $title',
        button: true,
        child: Material(
          color: color.withValues(alpha: actual ? 0.3 : 0.18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
            side: BorderSide(color: color),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('${actual ? 'actual' : 'planned'}-${block.id}'),
            onTap: widget.enabled
                ? () => widget.onOpen(block, actual: actual)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  actual ? '$title · ${block.status.label}' : title,
                  style: TextStyle(color: color, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatTimelineVariance(double hours) {
  final rounded = double.parse(hours.toStringAsPrecision(10));
  if (rounded == 0) return 'időben';
  return '${planningHours(rounded.abs())} óra ${rounded > 0 ? 'késés' : 'előny'}';
}
