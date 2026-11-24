import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/supabase_rescue_platform_api.dart';
import '../../models/member.dart';
import '../../services/app_store.dart';
import 'planning_board.dart';
import 'planning_injects_board.dart';
import 'planning_models.dart';
import 'planning_obstacles_board.dart';
import 'planning_repository.dart';
import 'planning_timeline_planner.dart';
import 'planning_victims_board.dart';

enum _PlanningTab { board, obstacles, victims, injects, timeline }

class ExercisePlanningScreen extends StatelessWidget {
  const ExercisePlanningScreen({super.key, this.onReturnToPortal});

  final VoidCallback? onReturnToPortal;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final api = store.api;
    final organizationId = store.currentOrganization?.id;
    final Widget body;
    if (!store.initialized) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!store.isAuthenticated && onReturnToPortal != null) {
      body = Center(
        child: TextButton(
          onPressed: onReturnToPortal,
          child: const Text('Bejelentkezés a csapatportálon'),
        ),
      );
    } else if (!store.isAuthenticated) {
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
        isAdmin: store.isAdmin,
        canCreateExercises: store.isAdmin || store.canAccessExcon,
        currentUserId: api.currentUserId,
        members: store.members,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gyakorlat tervezés'),
        leading: onReturnToPortal == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Vissza a csapatportálra',
                onPressed: onReturnToPortal,
              ),
      ),
      body: body,
    );
  }
}

class _PlanningWorkspace extends StatefulWidget {
  const _PlanningWorkspace({
    super.key,
    required this.repository,
    required this.isAdmin,
    required this.canCreateExercises,
    required this.currentUserId,
    required this.members,
  });

  final PlanningRepository repository;
  final bool isAdmin;
  final bool canCreateExercises;
  final String? currentUserId;
  final List<Member> members;

  @override
  State<_PlanningWorkspace> createState() => _PlanningWorkspaceState();
}

class _PlanningWorkspaceState extends State<_PlanningWorkspace> {
  late Future<List<Exercise>> _exercises;
  String? _selectedId;
  bool _creating = false;
  bool _savingBoard = false;
  _PlanningTab _activeTab = _PlanningTab.board;

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

  Future<void> _managePlanners(Exercise exercise) async {
    final currentIds =
        await widget.repository.fetchExercisePlanners(exercise.id);
    if (!mounted) return;
    final nextIds = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _ExercisePlannersDialog(
        exerciseTitle: exercise.title,
        members: widget.members,
        initialSelected: currentIds,
      ),
    );
    if (!mounted || nextIds == null) return;
    setState(() => _creating = true);
    try {
      await widget.repository.setExercisePlanners(
        exerciseId: exercise.id,
        previousIds: currentIds,
        nextIds: nextIds,
        assignedBy: widget.currentUserId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'EXCON hozzáférések mentve (${nextIds.length} kijelölt tag).',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Az EXCON hozzáférések mentése nem sikerült.'),
        ),
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
        if (!widget.canCreateExercises && exercises.isEmpty) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        'Zárt EXCON tervezőfelület',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A gyakorlatok tartalmát csak az Adminisztrátor, a gyakorlathoz EXCON-ként hozzárendelt tagok, valamint az eseményeknél Admin által jóváhagyott EXCON tagok láthatják.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final selectedExercise = _selectedId == null
            ? null
            : exercises.where((e) => e.id == _selectedId).firstOrNull;

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
                    final accessBtn = widget.isAdmin && selectedExercise != null
                        ? OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48)),
                            onPressed: _creating || _savingBoard
                                ? null
                                : () => _managePlanners(selectedExercise),
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('EXCON hozzáférés'),
                          )
                        : null;
                    final add = widget.canCreateExercises
                        ? FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48)),
                            onPressed: _creating || _savingBoard
                                ? null
                                : () => _createExercise(exercises),
                            icon: const Icon(Icons.add),
                            label: const Text('Új gyakorlat'),
                          )
                        : null;
                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          selector,
                          if (accessBtn != null) ...[
                            const SizedBox(height: 8),
                            accessBtn,
                          ],
                          if (add != null) ...[
                            const SizedBox(height: 8),
                            add,
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: selector),
                        if (accessBtn != null) ...[
                          const SizedBox(width: 12),
                          accessBtn,
                        ],
                        if (add != null) ...[
                          const SizedBox(width: 12),
                          add,
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_creating) const LinearProgressIndicator(),
            if (_selectedId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('1. Tervezőasztal & Pályák'),
                      selected: _activeTab == _PlanningTab.board,
                      onSelected: _savingBoard || _creating
                          ? null
                          : (_) =>
                              setState(() => _activeTab = _PlanningTab.board),
                    ),
                    ChoiceChip(
                      label: const Text('2. Akadályok'),
                      selected: _activeTab == _PlanningTab.obstacles,
                      onSelected: _savingBoard || _creating
                          ? null
                          : (_) => setState(
                              () => _activeTab = _PlanningTab.obstacles),
                    ),
                    ChoiceChip(
                      label: const Text('3. Sérültek felvétele'),
                      selected: _activeTab == _PlanningTab.victims,
                      onSelected: _savingBoard || _creating
                          ? null
                          : (_) =>
                              setState(() => _activeTab = _PlanningTab.victims),
                    ),
                    ChoiceChip(
                      label: const Text('4. Injektek'),
                      selected: _activeTab == _PlanningTab.injects,
                      onSelected: _savingBoard || _creating
                          ? null
                          : (_) =>
                              setState(() => _activeTab = _PlanningTab.injects),
                    ),
                    ChoiceChip(
                      label: const Text('5. Idővonal tervezés'),
                      selected: _activeTab == _PlanningTab.timeline,
                      onSelected: _savingBoard || _creating
                          ? null
                          : (_) => setState(
                              () => _activeTab = _PlanningTab.timeline),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _selectedId == null
                  ? Center(
                      child: Text(
                        exercises.isEmpty
                            ? 'Még nincs rögzített gyakorlat.'
                            : 'Válassz egy gyakorlatot.',
                      ),
                    )
                  : switch (_activeTab) {
                      _PlanningTab.board => PlanningBoard(
                          key: ValueKey('board-${_selectedId!}'),
                          exerciseId: _selectedId!,
                          repository: widget.repository,
                          onSavingChanged: (saving) =>
                              setState(() => _savingBoard = saving),
                        ),
                      _PlanningTab.victims => PlanningVictimsBoard(
                          key: ValueKey('victims-${_selectedId!}'),
                          exerciseId: _selectedId!,
                          repository: widget.repository,
                          onSavingChanged: (saving) =>
                              setState(() => _savingBoard = saving),
                        ),
                      _PlanningTab.injects => PlanningInjectsBoard(
                          key: ValueKey('injects-${_selectedId!}'),
                          exerciseId: _selectedId!,
                          repository: widget.repository,
                          onSavingChanged: (saving) =>
                              setState(() => _savingBoard = saving),
                        ),
                      _PlanningTab.obstacles => PlanningObstaclesBoard(
                          key: ValueKey('obstacles-${_selectedId!}'),
                          exerciseId: _selectedId!,
                          repository: widget.repository,
                          onSavingChanged: (saving) =>
                              setState(() => _savingBoard = saving),
                        ),
                      _PlanningTab.timeline => PlanningTimelinePlanner(
                          key: ValueKey('timeline-${_selectedId!}'),
                          exerciseId: _selectedId!,
                          repository: widget.repository,
                          onSavingChanged: (saving) =>
                              setState(() => _savingBoard = saving),
                        ),
                    },
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


class _ExercisePlannersDialog extends StatefulWidget {
  const _ExercisePlannersDialog({
    required this.exerciseTitle,
    required this.members,
    required this.initialSelected,
  });

  final String exerciseTitle;
  final List<Member> members;
  final Set<String> initialSelected;

  @override
  State<_ExercisePlannersDialog> createState() =>
      _ExercisePlannersDialogState();
}

class _ExercisePlannersDialogState extends State<_ExercisePlannersDialog> {
  late final Set<String> _selected = Set<String>.from(widget.initialSelected);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.members]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final filtered = sorted.where((m) {
      if (_query.isEmpty) return true;
      return m.name.toLowerCase().contains(_query) ||
          m.rank.toLowerCase().contains(_query);
    }).toList();

    return AlertDialog(
      title: Text('EXCON hozzáférés – ${widget.exerciseTitle}'),
      content: SizedBox(
        width: 440,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Jelöld be, mely csapattagok láthatják és szerkeszthetik EXCON-ként ennek a gyakorlatnak a tartalmát. (Az Admin és az eseményeknél jóváhagyott EXCON tagok automatikusan hozzáférnek.)',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Tag keresése név szerint',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Nincs a keresésnek megfelelő tag.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final m = filtered[index];
                        final checked = _selected.contains(m.id);
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          title: Text(m.name),
                          subtitle: m.rank.isNotEmpty ? Text(m.rank) : null,
                          onChanged: (val) => setState(() {
                            if (val == true) {
                              _selected.add(m.id);
                            } else {
                              _selected.remove(m.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text('Mentés (${_selected.length} fő)'),
        ),
      ],
    );
  }
}
