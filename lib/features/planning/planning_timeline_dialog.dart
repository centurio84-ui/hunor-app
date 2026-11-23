import 'package:flutter/material.dart';

import 'planning_catalog_panel.dart' show planningHours;
import 'planning_models.dart';

enum TimelineDialogAction { save, copy, delete }

class TimelineDialogResult {
  const TimelineDialogResult(
    this.action, {
    this.bubble,
    this.sectorId,
    this.timing,
    this.status = TimelineStatus.planned,
    this.notes = '',
  });

  final TimelineDialogAction action;
  final ExerciseBubble? bubble;
  final String? sectorId;
  final TimelineTiming? timing;
  final TimelineStatus status;
  final String notes;
}

class PlanningTimelineDialog extends StatefulWidget {
  const PlanningTimelineDialog({
    super.key,
    required this.bubbles,
    required this.sectors,
    required this.startsBySector,
    this.preferredSector,
    this.block,
    this.actual = false,
  });

  final List<ExerciseBubble> bubbles;
  final List<ExerciseSector> sectors;
  final Map<String?, double> startsBySector;
  final String? preferredSector;
  final ExerciseTimelineBlock? block;
  final bool actual;

  @override
  State<PlanningTimelineDialog> createState() => _PlanningTimelineDialogState();
}

class _PlanningTimelineDialogState extends State<PlanningTimelineDialog> {
  final _form = GlobalKey<FormState>();
  final _start = TextEditingController();
  final _duration = TextEditingController();
  final _notes = TextEditingController();
  late ExerciseBubble _bubble;
  String? _sectorId;
  late TimelineStatus _status;

  @override
  void initState() {
    super.initState();
    _bubble = widget.bubbles.first;
    final block = widget.block;
    _status = block?.status ?? TimelineStatus.planned;
    if (block == null) {
      _selectBubble(_bubble);
    } else {
      _sectorId = block.sectorId;
      _setTiming(widget.actual ? block.actual! : block.planned);
      _notes.text = block.notes;
    }
  }

  @override
  void dispose() {
    _start.dispose();
    _duration.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _selectBubble(ExerciseBubble bubble) {
    _bubble = bubble;
    final preferred = widget.preferredSector;
    _sectorId = preferred == '' ? null : preferred ?? bubble.sectorId;
    final estimate = bubble.estimatedHours ?? 0;
    _setTiming(TimelineTiming(
      widget.startsBySector[_sectorId] ?? 0,
      estimate > 0 ? estimate : 1,
    ));
  }

  void _setTiming(TimelineTiming timing) {
    _start.text = planningHours(timing.start);
    _duration.text = planningHours(timing.duration);
  }

  double? _number(String? text) =>
      double.tryParse((text ?? '').trim().replaceAll(',', '.'));

  String? _validateStart(String? value) {
    final start = _number(value);
    return start == null || !start.isFinite || start < 0
        ? 'Adj meg egy nem negatív kezdőórát.'
        : null;
  }

  String? _validateDuration(String? value) {
    final duration = _number(value);
    if (duration == null || !duration.isFinite || duration <= 0) {
      return 'Az időtartam legyen nagyobb nullánál.';
    }
    final start = _number(_start.text);
    if (start != null &&
        start.isFinite &&
        start >= 0 &&
        !TimelineTiming(start, duration).isValid) {
      return 'A befejezési idő túl nagy.';
    }
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      TimelineDialogResult(
        TimelineDialogAction.save,
        bubble: _bubble,
        sectorId: _sectorId,
        timing: TimelineTiming(_number(_start.text)!, _number(_duration.text)!),
        status: _status,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.block == null;
    return AlertDialog(
      scrollable: true,
      title: Text(creating
          ? 'Buborék hozzáadása az idővonalhoz'
          : widget.actual
              ? 'Real időzítés'
              : 'Tervezett időzítés'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (creating)
                DropdownButtonFormField<ExerciseBubble>(
                  initialValue: _bubble,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Buborék'),
                  items: [
                    for (final bubble in widget.bubbles)
                      DropdownMenuItem(
                        value: bubble,
                        child:
                            Text(bubble.title, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (bubble) {
                    if (bubble != null) setState(() => _selectBubble(bubble));
                  },
                )
              else
                Text(_bubble.title,
                    style: Theme.of(context).textTheme.titleMedium),
              if (!widget.actual)
                DropdownButtonFormField<String>(
                  key: ValueKey(_bubble.id),
                  initialValue: _sectorId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pálya'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Közös célok')),
                    for (final sector in widget.sectors)
                      DropdownMenuItem(
                          value: sector.id, child: Text(sector.name)),
                  ],
                  onChanged: (value) {
                    _sectorId = value == '' ? null : value;
                    if (creating) {
                      _start.text =
                          planningHours(widget.startsBySector[_sectorId] ?? 0);
                    }
                  },
                ),
              TextFormField(
                controller: _start,
                decoration: const InputDecoration(
                    labelText: 'Kezdés a STARTEX-től (óra)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: _validateStart,
              ),
              TextFormField(
                controller: _duration,
                decoration: const InputDecoration(labelText: 'Időtartam (óra)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: _validateDuration,
              ),
              if (widget.actual)
                DropdownButtonFormField<TimelineStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Állapot'),
                  items: [
                    for (final status in TimelineStatus.values)
                      DropdownMenuItem(
                          value: status,
                          child: Text(status.label,
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) {
                    if (value != null) _status = value;
                  },
                )
              else
                TextFormField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Megjegyzés'),
                  maxLines: 2,
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (!creating && !widget.actual) ...[
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const TimelineDialogResult(TimelineDialogAction.delete),
            ),
            child: const Text('Blokk törlése'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const TimelineDialogResult(TimelineDialogAction.copy),
            ),
            child: const Text('Másolás Real-re'),
          ),
        ],
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse')),
        FilledButton(
            onPressed: _save, child: Text(creating ? 'Hozzáadás' : 'Mentés')),
      ],
    );
  }
}
