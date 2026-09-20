import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final u = s.currentUser;
    if (u == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: HunorColors.redDark,
                  child: Icon(Icons.person, size: 34),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(u.rank, style: const TextStyle(color: HunorColors.red, fontWeight: FontWeight.w800)),
                      Text(u.position, style: const TextStyle(color: HunorColors.muted)),
                      Text(u.workplace, style: const TextStyle(color: HunorColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: Icon(
              u.status == AvailabilityStatus.available
                  ? Icons.check_circle
                  : Icons.event_busy,
              color: u.status == AvailabilityStatus.available
                  ? HunorColors.success
                  : HunorColors.warning,
            ),
            title: const Text('Elérhetőség', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(u.status.label, style: const TextStyle(color: HunorColors.muted)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editAvailability(context, s, u.status),
          ),
        ),
        const SizedBox(height: 10),
        Text('Képességek', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (u.skills.isEmpty)
                  const Text('Nincs megadott képesség', style: TextStyle(color: HunorColors.muted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final x in u.skills) Chip(label: Text(x))],
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _editSkills(context, s, u.skills),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Képességek szerkesztése'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: s.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Kijelentkezés'),
        ),
      ],
    );
  }

  static Future<void> _editAvailability(
    BuildContext context,
    AppStore s,
    AvailabilityStatus current,
  ) async {
    var status = current;
    DateTime start = DateTime.now();
    DateTime? end;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Elérhetőség beállítása'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AvailabilityStatus>(
                value: status,
                decoration: const InputDecoration(labelText: 'Állapot'),
                items: const [
                  DropdownMenuItem(value: AvailabilityStatus.available, child: Text('Elérhető')),
                  DropdownMenuItem(value: AvailabilityStatus.vacation, child: Text('Szabadságon')),
                  DropdownMenuItem(value: AvailabilityStatus.sick, child: Text('Beteg')),
                  DropdownMenuItem(value: AvailabilityStatus.training, child: Text('Képzésen')),
                  DropdownMenuItem(value: AvailabilityStatus.unavailable, child: Text('Egyéb / nem elérhető')),
                ],
                onChanged: (v) => v == null ? null : set(() => status = v),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kezdőnap'),
                subtitle: Text(_date(start)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: c,
                    initialDate: start,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (d != null) set(() => start = d);
                },
              ),
              if (status != AvailabilityStatus.available)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Végdátum'),
                  subtitle: Text(end == null ? 'Nincs megadva' : _date(end!)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: c,
                      initialDate: end ?? start,
                      firstDate: start,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) set(() => end = d);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Mégse')),
            FilledButton(
              onPressed: () async {
                if (status != AvailabilityStatus.available &&
                    end != null &&
                    end!.isBefore(start)) return;
                await s.setAvailability(status, startDate: start, endDate: end);
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Mentés'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _editSkills(
    BuildContext context,
    AppStore s,
    List<String> skills,
  ) async {
    final controller = TextEditingController(text: skills.join(', '));
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Képességek'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Képességek',
            hintText: 'pl. Shoring, Medic, Alpine',
            helperText: 'Vesszővel válaszd el a képességeket.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () async {
              final values = controller.text.split(',');
              await s.replaceOwnSkills(values);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  static String _date(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
