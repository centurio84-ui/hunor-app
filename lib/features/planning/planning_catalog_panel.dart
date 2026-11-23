import 'package:flutter/material.dart';

import '../../theme/hunor_theme.dart';
import 'planning_models.dart';
import 'planning_repository.dart';

String planningHours(num value) =>
    (value is double && value == value.truncateToDouble()
            ? value.toStringAsFixed(0)
            : value.toString())
        .replaceAll('.', ',');

Widget planningDragFeedback(String title) => Material(
      color: HunorColors.surface2,
      elevation: 6,
      borderRadius: BorderRadius.circular(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );

class PlanningCatalogPanel extends StatefulWidget {
  const PlanningCatalogPanel({
    super.key,
    required this.repository,
    required this.enabled,
    required this.onAddCustom,
    required this.onAddCheckpoint,
  });

  final PlanningRepository repository;
  final bool enabled;
  final VoidCallback onAddCustom;
  final ValueChanged<InsaragCheckpoint> onAddCheckpoint;

  @override
  State<PlanningCatalogPanel> createState() => _PlanningCatalogPanelState();
}

class _PlanningCatalogPanelState extends State<PlanningCatalogPanel> {
  static const _categories = ['ASR', 'SEARCH', 'RESCUE', 'COORDINATION'];
  late Future<List<InsaragCheckpoint>> _catalog;
  String? _category;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _catalog = widget.repository.fetchCheckpointCatalog();
  }

  Iterable<InsaragCheckpoint> _filter(List<InsaragCheckpoint> catalog) =>
      catalog.where((item) {
        return (_category == null ||
                item.category?.toUpperCase() == _category) &&
            [item.code, item.titleHu, item.titleEn]
                .any((field) => field?.toLowerCase().contains(_query) ?? false);
      });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('INSARAG ellenőrzőpontok',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: widget.enabled ? widget.onAddCustom : null,
            icon: const Icon(Icons.add),
            label: const Text('Egyedi cél buborék'),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Keresés a katalógusban',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (text) =>
                setState(() => _query = text.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in <String?>[null, ..._categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(category ?? 'Összes'),
                      selected: _category == category,
                      onSelected: (selected) => setState(
                          () => _category = selected ? category : null),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FutureBuilder<List<InsaragCheckpoint>>(
              future: _catalog,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ListView(
                    primary: false,
                    children: [
                      const Text('A katalógus betöltése nem sikerült.'),
                      TextButton(
                        onPressed: () => setState(() {
                          _catalog = widget.repository.fetchCheckpointCatalog();
                        }),
                        child: const Text('Újrapróbálás'),
                      ),
                    ],
                  );
                }

                final catalog = snapshot.requireData;
                final filtered = _filter(catalog).toList();
                if (filtered.isEmpty) {
                  return ListView(
                    primary: false,
                    children: [
                      Text(catalog.isEmpty
                          ? 'A katalógus még üres. Egyedi célt már hozzáadhatsz.'
                          : 'Nincs a szűrésnek megfelelő ellenőrzőpont.'),
                    ],
                  );
                }

                return ListView.separated(
                  primary: false,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) =>
                      _checkpointCard(filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkpointCard(InsaragCheckpoint item) {
    final duration = item.defaultDurationHours;
    final card = Card(
      margin: EdgeInsets.zero,
      color: HunorColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        title: Text(item.titleHu),
        subtitle: Text([
          if (item.code case final code?) code,
          duration == null ? 'Nincs alapidő' : '${planningHours(duration)} óra',
        ].join(' · ')),
        trailing: const Icon(Icons.add_circle_outline),
        enabled: widget.enabled,
        onTap: widget.enabled ? () => widget.onAddCheckpoint(item) : null,
      ),
    );

    return Draggable<InsaragCheckpoint>(
      data: item,
      maxSimultaneousDrags: widget.enabled ? 1 : 0,
      feedback: planningDragFeedback(item.titleHu),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }
}
