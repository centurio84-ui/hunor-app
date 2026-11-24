import 'package:flutter/material.dart';

import '../../theme/hunor_theme.dart';
import 'planning_models.dart';
import 'planning_repository.dart';

String planningHours(num value) =>
    (value is double && value == value.truncateToDouble()
            ? value.toStringAsFixed(0)
            : value.toString())
        .replaceAll('.', ',');

Widget planningDragFeedback(String title, {Color? accentColor}) => Material(
      color: HunorColors.surface2,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor ?? HunorColors.gold,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
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
  late Future<List<InsaragCheckpoint>> _catalog;
  String? _selectedSection;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _catalog = widget.repository.fetchCheckpointCatalog();
  }

  Iterable<InsaragCheckpoint> _filter(List<InsaragCheckpoint> catalog) =>
      catalog.where((item) {
        final matchesSection = _selectedSection == null ||
            item.category?.toUpperCase() == _selectedSection!.toUpperCase();
        if (!matchesSection) return false;
        if (_query.isEmpty) return true;
        return [item.code, item.titleHu, item.titleEn, item.clarificationHu]
            .any((field) => field?.toLowerCase().contains(_query) ?? false);
      });

  List<({String key, String label, Color color, int count})> _buildSections(
    List<InsaragCheckpoint> catalog,
  ) {
    final counts = <String, int>{};
    for (final item in catalog) {
      final cat = item.category;
      if (cat != null && cat.isNotEmpty) {
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
    }

    final result = <({String key, String label, Color color, int count})>[];
    for (final section in InsaragSection.all) {
      final count = counts.remove(section.key) ?? 0;
      if (count > 0) {
        result.add((
          key: section.key,
          label: section.label,
          color: section.color,
          count: count,
        ));
      }
    }
    // Esetleges korábbi / egyedi kategóriák (pl. tesztekben)
    for (final entry in counts.entries) {
      result.add((
        key: entry.key,
        label: entry.key,
        color: HunorColors.gold,
        count: entry.value,
      ));
    }
    return result;
  }

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
                final sections = _buildSections(catalog);
                final validSelected = _selectedSection != null &&
                        sections.any((s) => s.key == _selectedSection)
                    ? _selectedSection
                    : null;
                final filtered = _filter(catalog).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sections.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: validSelected,
                        decoration: const InputDecoration(
                          labelText: 'INSARAG főmenü / szekció',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Összes szekció (${catalog.length} pont)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final sec in sections)
                            DropdownMenuItem<String?>(
                              value: sec.key,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: sec.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${sec.label} (${sec.count})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedSection = value),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Expanded(
                      child: filtered.isEmpty
                          ? ListView(
                              primary: false,
                              children: [
                                Text(catalog.isEmpty
                                    ? 'A katalógus még üres. Egyedi célt már hozzáadhatsz.'
                                    : 'Nincs a szűrésnek megfelelő ellenőrzőpont.'),
                              ],
                            )
                          : ListView.separated(
                              primary: false,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) =>
                                  _checkpointCard(filtered[index]),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkpointCard(InsaragCheckpoint item) {
    final section = item.section;
    final accent = section?.color ?? HunorColors.gold;
    final shortCode = item.code?.replaceFirst('INSARAG-', '');

    final card = Card(
      margin: EdgeInsets.zero,
      color: HunorColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withValues(alpha: 0.55), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.enabled ? () => widget.onAddCheckpoint(item) : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (shortCode != null || section != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (shortCode != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  shortCode,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ),
                            if (section != null)
                              Text(
                                section.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: accent.withValues(alpha: 0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    Text(
                      item.titleHu,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.clarificationHu != null &&
                        item.clarificationHu!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          item.clarificationHu!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: HunorColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.add_circle_outline,
                size: 20,
                color: widget.enabled ? accent : HunorColors.muted,
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<InsaragCheckpoint>(
      data: item,
      maxSimultaneousDrags: widget.enabled ? 1 : 0,
      feedback: planningDragFeedback(item.titleHu, accentColor: accent),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }
}
