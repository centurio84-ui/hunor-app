import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/supabase_rescue_platform_api.dart';
import '../../services/app_store.dart';
import 'planning_board.dart';
import 'planning_models.dart';
import 'planning_repository.dart';

class ExercisePlanningScreen extends StatelessWidget {
  const ExercisePlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final api = store.api;
    final organizationId = store.currentOrganization?.id;
    final Widget body;
    if (!store.initialized) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!store.isAuthenticated || !store.canAccessExcon) {
      body = const Center(child: Text('Nincs jogosultságod a tervezéshez.'));
    } else if (api is! SupabaseRescuePlatformApi || organizationId == null) {
      body = const Center(child: Text('A tervezés jelenleg nem érhető el.'));
    } else {
      body = _PlanningWorkspace(
        key: ValueKey((api.client, organizationId, api.currentUserId)),
        repository: PlanningRepository(
          api.client,
          organizationId: organizationId,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gyakorlat tervezés')),
      body: body,
    );
  }
}

class _PlanningWorkspace extends StatefulWidget {
  const _PlanningWorkspace({super.key, required this.repository});

  final PlanningRepository repository;

  @override
  State<_PlanningWorkspace> createState() => _PlanningWorkspaceState();
}

class _PlanningWorkspaceState extends State<_PlanningWorkspace> {
  late Future<List<Exercise>> _exercises;
  String? _selectedId;
  bool _creating = false;
  bool _savingBoard = false;

  @override
  void initState() {
    super.initState();
    _exercises = widget.repository.listExercises();
  }

  Future<void> _createExercise(List<Exercise> exercises) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _NewExerciseDialog(),
    );
    if (!mounted || title == null) return;

    setState(() => _creating = true);
    try {
      final exercise = await widget.repository.createExercise(title);
      if (!mounted) return;
      setState(() {
        _exercises = Future.value([exercise, ...exercises]);
        _selectedId = exercise.id;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A gyakorlat létrehozása nem sikerült.')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Exercise>>(
      future: _exercises,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(
            message: 'A gyakorlatok betöltése nem sikerült.',
            onRetry: () => setState(() {
              _exercises = widget.repository.listExercises();
            }),
          );
        }

        final exercises = snapshot.requireData;
        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final selector = DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedId,
                      hint: const Text('Gyakorlat kiválasztása'),
                      items: [
                        for (final exercise in exercises)
                          DropdownMenuItem(
                            value: exercise.id,
                            child: Text(
                              exercise.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _creating || _savingBoard || exercises.isEmpty
                          ? null
                          : (id) {
                              if (id != null) {
                                setState(() => _selectedId = id);
                              }
                            },
                    );
                    final add = FilledButton.icon(
                      onPressed: _creating || _savingBoard
                          ? null
                          : () => _createExercise(exercises),
                      icon: const Icon(Icons.add),
                      label: const Text('Új gyakorlat'),
                    );
                    if (constraints.maxWidth < 420) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [selector, const SizedBox(height: 8), add],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: selector),
                        const SizedBox(width: 16),
                        add,
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_creating) const LinearProgressIndicator(),
            Expanded(
              child: _selectedId == null
                  ? Center(
                      child: Text(
                        exercises.isEmpty
                            ? 'Még nincs rögzített gyakorlat.'
                            : 'Válassz egy gyakorlatot.',
                      ),
                    )
                  : PlanningBoard(
                      key: ValueKey(_selectedId),
                      exerciseId: _selectedId!,
                      repository: widget.repository,
                      onSavingChanged: (saving) =>
                          setState(() => _savingBoard = saving),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NewExerciseDialog extends StatefulWidget {
  const _NewExerciseDialog();

  @override
  State<_NewExerciseDialog> createState() => _NewExerciseDialogState();
}

class _NewExerciseDialogState extends State<_NewExerciseDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _title.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Új gyakorlat'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _title,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Gyakorlat neve'),
          textInputAction: TextInputAction.done,
          validator: (value) => (value ?? '').trim().isEmpty
              ? 'Add meg a gyakorlat nevét.'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mégse'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Létrehozás')),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(onPressed: onRetry, child: const Text('Újrapróbálás')),
          ],
        ),
      ),
    );
  }
}
