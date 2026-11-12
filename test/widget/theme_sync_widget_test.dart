import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hunor_app/services/theme_controller.dart';
import 'package:hunor_app/services/theme_vault.dart';
import '../api/theme_controller_test.dart' show TestThemeService;

void main() {
  testWidgets('ThemeController dynamically updates MaterialApp theme and widgets react', (tester) async {
    final vault = InMemoryThemeVault();
    final service = TestThemeService();
    final controller = ThemeController(themeService: service, themeVault: vault);
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
                  title: Text(themeCtrl.currentDefinition.name),
                ),
                body: Builder(
                  builder: (ctx) {
                    final primary = Theme.of(ctx).colorScheme.primary;
                    return Center(
                      child: Container(
                        key: const ValueKey('color-box'),
                        color: primary,
                        child: Text('Theme ID: ${themeCtrl.currentThemeId}'),
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
    await controller.setTheme('weekday-04-medic');
    await tester.pumpAndSettle();

    expect(find.text('Medic'), findsOneWidget);
    expect(find.text('Theme ID: weekday-04-medic'), findsOneWidget);

    // Szín ellenőrzése (Medic smaragdzöld: 0xFF10B981)
    final boxWidget = tester.widget<Container>(find.byKey(const ValueKey('color-box')));
    expect(boxWidget.color, const Color(0xFF10B981));

    controller.dispose();
    service.dispose();
  });
}
