import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/navigation_controller.dart';
import 'navigation_gate.dart';
class NavigationSettingsPage extends StatelessWidget {
  const NavigationSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => NavigationGate(path: '/navigation-settings', builder: (context) {
    final navigation = context.watch<NavigationController>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Menük kezelése', style: Theme.of(context).textTheme.headlineSmall),
      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text(
        'A kapcsolók a tagok hozzáférését szabályozzák. Az admin a rejtett füleket is látja. A szerepköri jogosultságok megmaradnak.')),
      for (final tab in navigation.tabs) SwitchListTile.adaptive(
        key: ValueKey(tab.id), title: Text(tab.title),
        subtitle: Text('${tab.routePath} · ${tab.isVisible ? "Bekapcsolva" : "Rejtett · fejlesztés alatt"}'),
        value: tab.isVisible,
        onChanged: navigation.saving.contains(tab.id) ? null : (value) async {
          try { await navigation.setVisible(tab, value); }
          catch (_) {if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A mentés nem sikerült. Ellenőrizd a kapcsolatot és az adminjogosultságot.')));}
        },
      ),
    ]);
  });
}
