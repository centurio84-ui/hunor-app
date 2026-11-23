import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/main.dart';
import 'package:hunor_app/services/app_store.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Direct planning access requires the EXCON permission',
      (tester) async {
    final store = AppStore()
      ..initialized = true
      ..isAuthenticated = true;
    addTearDown(store.dispose);

    tester.platformDispatcher.defaultRouteNameTestValue = '/planning';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const HunorApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nincs jogosultságod a tervezéshez.'), findsOneWidget);
    expect(find.text('Új gyakorlat'), findsNothing);
  });

  testWidgets('Portal planning opens at root and returns users to portal login',
      (tester) async {
    final store = AppStore()..initialized = true;
    addTearDown(store.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const HunorApp(portalPlanning: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gyakorlat tervezés'), findsOneWidget);
    expect(find.text('Bejelentkezés a csapatportálon'), findsOneWidget);
    expect(find.byTooltip('Vissza a csapatportálra'), findsOneWidget);
    expect(find.text('Új gyakorlat'), findsNothing);
  });
}
