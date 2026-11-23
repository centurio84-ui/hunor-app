import 'package:flutter/material.dart';

import 'planning_catalog_panel.dart' show planningHours;
import 'planning_models.dart';

class PlanningBubbleEdit {
  const PlanningBubbleEdit({
    this.title = '',
    this.estimatedHours,
    this.discipline = BubbleDiscipline.custom,
    this.specs = const {},
    this.delete = false,
  });

  final String title;
  final double? estimatedHours;
  final BubbleDiscipline discipline;
  final Map<String, dynamic> specs;
  final bool delete;
}

class PlanningBubbleDialog extends StatefulWidget {
  const PlanningBubbleDialog({
    super.key,
    this.bubble,
    this.initialDiscipline = BubbleDiscipline.custom,
  });

  final ExerciseBubble? bubble;
  final BubbleDiscipline initialDiscipline;

  @override
  State<PlanningBubbleDialog> createState() => _PlanningBubbleDialogState();
}

class _PlanningBubbleDialogState extends State<PlanningBubbleDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _hours = TextEditingController();
  static const _technical = {
    'wall_thickness_cm': 'Falvastagság (cm)',
    'orientation': 'Tájolás',
    'shoring_type': 'Dúcolás típusa',
    'notes': 'Megjegyzések',
  };
  static const _fields = {
    BubbleDiscipline.checkpoint: _technical,
    BubbleDiscipline.custom: _technical,
    BubbleDiscipline.medical: {
      'clinical_scenario': 'Sérülés vagy klinikai helyzet',
      'patient_count': 'Becsült betegszám',
      'medical_notes': 'Kimentés, ellátás és kiürítés',
    },
    BubbleDiscipline.ucc: {
      'coordination_role': 'Koordinációs vagy törzsszerep / csapat',
      'inject_trigger': 'Szituációindító esemény',
      'coordination_notes': 'Koordinációs megjegyzések',
    },
    BubbleDiscipline.pressVip: {
      'stakeholder_type': 'Érintett típusa',
      'protocol_notes': 'Tájékoztatás, kíséret, média és belépés',
    },
  };
  static const _stakeholders = ['Sajtó', 'VIP', 'LEMA'];
  static const _multiline = {
    'notes',
    'medical_notes',
    'coordination_notes',
    'protocol_notes',
  };
  late BubbleDiscipline _discipline;
  final _specs = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final bubble = widget.bubble;
    _discipline = bubble?.discipline ?? widget.initialDiscipline;
    _title.text = bubble?.title ?? '';
    if (bubble?.estimatedHours case final hours?) {
      _hours.text = planningHours(hours);
    }
    for (final key in _fields.values.expand((fields) => fields.keys).toSet()) {
      final value = bubble?.specs[key];
      _specs[key] = TextEditingController(
        text: value is num ? planningHours(value) : value?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _hours.dispose();
    for (final controller in _specs.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = _number(value);
    return parsed == null || !parsed.isFinite || parsed < 0
        ? 'Adj meg egy nem negatív számot.'
        : null;
  }

  String? _validatePatientCount(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;
    final count = int.tryParse(input);
    return count == null || count < 0
        ? 'Adj meg egy nem negatív egész számot.'
        : null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final specs = <String, dynamic>{...?widget.bubble?.specs};
    for (final key in _fields[_discipline]!.keys) {
      final value = _specs[key]!.text.trim();
      if (value.isEmpty) {
        specs.remove(key);
      } else {
        specs[key] = switch (key) {
          'wall_thickness_cm' => _number(value),
          'patient_count' => int.parse(value),
          _ => value,
        };
      }
    }

    Navigator.pop(
        context,
        PlanningBubbleEdit(
          title: _title.text.trim(),
          discipline: _discipline,
          estimatedHours: _number(_hours.text),
          specs: specs,
        ));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buborék törlése'),
        content: const Text(
            'Törlöd a buborékot és a hozzá tartozó idővonalblokkot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      Navigator.pop(context, const PlanningBubbleEdit(delete: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.bubble != null;
    return AlertDialog(
      title: Text(editing
          ? 'Buborék szerkesztése'
          : widget.initialDiscipline == BubbleDiscipline.custom
              ? 'Egyedi cél buborék'
              : 'Új szakági buborék'),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_discipline != BubbleDiscipline.checkpoint)
              DropdownButtonFormField<BubbleDiscipline>(
                initialValue: _discipline,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Szakág'),
                items: [
                  for (final type in BubbleDiscipline.values)
                    if (type != BubbleDiscipline.checkpoint)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (type) {
                  if (type != null) setState(() => _discipline = type);
                },
              ),
            TextFormField(
              controller: _title,
              autofocus: !editing,
              decoration: const InputDecoration(labelText: 'Cím'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Add meg a buborék címét.'
                  : null,
            ),
            TextFormField(
              controller: _hours,
              decoration: const InputDecoration(labelText: 'Becsült idő (óra)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _validateNumber,
            ),
            for (final entry in _fields[_discipline]!.entries)
              if (entry.key == 'stakeholder_type')
                DropdownButtonFormField<String>(
                  key: const ValueKey('stakeholder_type'),
                  isExpanded: true,
                  initialValue: _stakeholders.contains(_specs[entry.key]!.text)
                      ? _specs[entry.key]!.text
                      : null,
                  decoration: InputDecoration(labelText: entry.value),
                  items: [
                    for (final type in _stakeholders)
                      DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: (value) => _specs[entry.key]!.text = value ?? '',
                )
              else
                TextFormField(
                  key: ValueKey(entry.key),
                  controller: _specs[entry.key],
                  decoration: InputDecoration(labelText: entry.value),
                  keyboardType: switch (entry.key) {
                    'wall_thickness_cm' =>
                      const TextInputType.numberWithOptions(decimal: true),
                    'patient_count' => TextInputType.number,
                    _ => null,
                  },
                  validator: switch (entry.key) {
                    'wall_thickness_cm' => _validateNumber,
                    'patient_count' => _validatePatientCount,
                    _ => null,
                  },
                  maxLines: _multiline.contains(entry.key) ? 3 : 1,
                ),
          ],
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: _confirmDelete,
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Törlés'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse')),
        FilledButton(
            onPressed: _submit, child: Text(editing ? 'Mentés' : 'Létrehozás')),
      ],
    );
  }
}
