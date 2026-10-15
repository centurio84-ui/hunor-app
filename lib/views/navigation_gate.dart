import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/navigation_controller.dart';
class NavigationGate extends StatelessWidget {
  const NavigationGate({super.key, required this.path, required this.builder});
  final String path;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationController>();
    if (navigation.canOpen(path)) return builder(context);
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.construction_rounded, size: 48), const SizedBox(height: 16),
        Text(navigation.error ?? (navigation.ready
          ? 'A funkció jelenleg fejlesztés alatt áll, vagy nem rendelkezel hozzá jogosultsággal.'
          : 'Menübeállítások betöltése…'), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(onPressed: navigation.refresh, child: const Text('Újrapróbálás')),
      ],
    )));
  }
}
