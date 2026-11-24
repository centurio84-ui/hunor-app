import 'package:flutter/material.dart';

import 'planning_models.dart';

class PlanningSectorEdit {
  const PlanningSectorEdit({
    required this.name,
    required this.icmsName,
    required this.description,
    this.delete = false,
  });

  final String name;
  final String icmsName;
  final String description;
  final bool delete;
}

class PlanningSectorDialog extends StatefulWidget {
  const PlanningSectorDialog({super.key, this.sector});

  final ExerciseSector? sector;

  @override
  State<PlanningSectorDialog> createState() => _PlanningSectorDialogState();
}

class _PlanningSectorDialogState extends State<PlanningSectorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _icmsName;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.sector?.name ?? '');
    _icmsName = TextEditingController(text: widget.sector?.icmsName ?? '');
    _description =
        TextEditingController(text: widget.sector?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _icmsName.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      PlanningSectorEdit(
        name: _name.text.trim(),
        icmsName: _icmsName.text.trim(),
        description: _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.sector != null;
    return AlertDialog(
      title: Text(editing ? 'Pálya szerkesztése' : 'Új pálya felvétele'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Pálya neve *',
                    hintText: 'pl. ROM 1 – Északi lakóház',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Add meg a pálya nevét.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _icmsName,
                  decoration: const InputDecoration(
                    labelText: 'ICMS elnevezés (csapat által használt név)',
                    hintText: 'pl. HUN-A-01 / Sector Alpha',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Pálya leírása',
                    hintText: 'Épülettípus, sérültek, veszélyek, megjegyzések...',
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
              const PlanningSectorEdit(
                name: '',
                icmsName: '',
                description: '',
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
          child: Text(editing ? 'Mentés' : 'Létrehozás'),
        ),
      ],
    );
  }
}
