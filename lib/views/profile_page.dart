import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                const CircleAvatar(radius: 34, backgroundColor: HunorColors.redDark, child: Icon(Icons.person, size: 34)),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: HunorColors.success, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                const Text('Aktuális állapot', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(u.status.label, style: const TextStyle(color: HunorColors.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('Képességek', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: u.skills.isEmpty
              ? const Text('Nincs megadott képesség', style: TextStyle(color: HunorColors.muted))
              : Wrap(spacing: 8, runSpacing: 8, children: [for (final x in u.skills) Chip(label: Text(x))]),
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(onPressed: s.signOut, icon: const Icon(Icons.logout), label: const Text('Kijelentkezés')),
      ],
    );
  }
}