import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});
  @override State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final query = q.toLowerCase().trim();
    final list = s.members.where((m) =>
      m.name.toLowerCase().contains(query) ||
      m.skills.any((x) => x.toLowerCase().contains(query))
    ).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: TextField(
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Név vagy képesség',
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
            ? const Center(child: Text('Nincs találat', style: TextStyle(color: HunorColors.muted)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: list.length,
                itemBuilder: (c, i) {
                  final m = list[i];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: HunorColors.surface2,
                        child: Text(m.name.isEmpty ? '?' : m.name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        '${m.rank} • ${m.position}\\n${m.status.label}',
                        style: const TextStyle(color: HunorColors.muted),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right, color: HunorColors.muted),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}