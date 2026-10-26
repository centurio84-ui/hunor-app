import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hunor_app/models/theme_config.dart';
import 'package:hunor_app/services/theme_controller.dart';
import 'package:hunor_app/services/theme_vault.dart';
import 'theme_controller_test.dart' show FakeThemeService;

void main() {
  testWidgets('ThemeController dynamically updates MaterialApp theme and widgets react', (tester) async {
    final vault = InMemoryThemeVault();
    final service = FakeThemeService();
    final controller = ThemeController(themeService: service, vault: vault);
    await controller.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeController>.value(
        value: controller,
        child: Consumer<ThemeController>(
          builder: (context, themeCtrl, _) {
            return MaterialApp(
              theme: themeCtrl.currentTheme,
              home: Scaffold(
                appBar: AppBar(
                  title: Text(themeCtrl.currentThemeDefinition.name),
                ),
                body: Builder(
                  builder: (ctx) {
                    final primary = Theme.of(ctx).colorScheme.primary;
                    return Center(
                      child: Container(
                        key: const ValueKey('color-box'),
                        color: primary,
                        child: Text('Theme ID: ${themeCtrl.activeThemeId}'),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    // Kezdeti állapot: Alpin
    expect(find.text('Alpin'), findsOneWidget);
    expect(find.text('Theme ID: weekday-01-alpin'), findsOneWidget);

    // Téma váltás Medic-re
    await controller.setTheme('weekday-04-medic', 'org-1');
    await tester.pumpAndSettle();

    expect(find.text('Medic'), findsOneWidget);
    expect(find.text('Theme ID: weekday-04-medic'), findsOneWidget);

    // Szín ellenőrzése
    final boxWidget = tester.widget<Container>(find.byKey(const ValueKey('color-box')));
    expect(boxWidget.color, const Color(0xFF00BFA5));

    controller.dispose();
    service.dispose();
  });
}
