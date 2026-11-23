import 'package:flutter/material.dart';

import 'planning_catalog_panel.dart' show planningHours;
import 'planning_models.dart';

class PlanningBubbleEdit {
  const PlanningBubbleEdit({
    this.title = '',
    this.estimatedHours,
    this.specs = const {},
    this.delete = false,
  });

  final String title;
  final double? estimatedHours;
  final Map<String, dynamic> specs;
  final bool delete;
}

class PlanningBubbleDialog extends StatefulWidget {
  const PlanningBubbleDialog({super.key, this.bubble});

  final ExerciseBubble? bubble;

  @override
  State<PlanningBubbleDialog> createState() => _PlanningBubbleDialogState();
}

class _PlanningBubbleDialogState extends State<PlanningBubbleDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _hours = TextEditingController();
  static const _specLabels = {
    'wall_thickness_cm': 'Falvastagság (cm)',
    'orientation': 'Tájolás',
    'shoring_type': 'Dúcolás típusa',
    'notes': 'Megjegyzések',
  };
  final _specs = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final bubble = widget.bubble;
    _title.text = bubble?.title ?? '';
    if (bubble?.estimatedHours case final hours?) {
      _hours.text = planningHours(hours);
    }
    for (final key in _specLabels.keys) {
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

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final specs = <String, dynamic>{...?widget.bubble?.specs};
    for (final entry in _specs.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        specs.remove(entry.key);
      } else {
        specs[entry.key] =
            entry.key == 'wall_thickness_cm' ? _number(value) : value;
      }
    }

    Navigator.pop(
        context,
        PlanningBubbleEdit(
          title: _title.text.trim(),
          estimatedHours: _number(_hours.text),
          specs: specs,
        ));
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Buborék törlése'),
        content: const Text('Biztosan törlöd ezt a buborékot?'),
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
      title: Text(editing ? 'Buborék szerkesztése' : 'Egyedi cél buborék'),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            for (final entry in _specLabels.entries)
              TextFormField(
                controller: _specs[entry.key],
                decoration: InputDecoration(labelText: entry.value),
                keyboardType: entry.key == 'wall_thickness_cm'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : null,
                validator:
                    entry.key == 'wall_thickness_cm' ? _validateNumber : null,
                maxLines: entry.key == 'notes' ? 3 : 1,
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
