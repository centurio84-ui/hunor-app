import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hunor_app/api/mock_rescue_platform_api.dart';
import 'package:hunor_app/services/app_store.dart';
import 'package:hunor_app/views/alerts_page.dart';
import 'package:hunor_app/views/calendar_page.dart';
import 'package:hunor_app/views/login_page.dart';
import 'package:hunor_app/views/profile_page.dart';
import 'package:hunor_app/views/app_shell.dart';
import 'package:hunor_app/theme/hunor_theme.dart';

void main() {
  group('Rescue Platform Flutter MVP – Felhasználói Folyamatok és Adatelkülönítés', () {
    late MockRescuePlatformApi mockApi;
    late AppStore store;

    setUp(() {
      mockApi = MockRescuePlatformApi();
      store = AppStore(api: mockApi);
    });

    Widget createTestApp({Widget? home}) {
      return ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: MaterialApp(
          theme: HunorTheme.dark,
          home: home != null
              ? Scaffold(body: home)
              : Consumer<AppStore>(
                  builder: (context, s, _) =>
                      s.isAuthenticated ? const AppShell() : const LoginPage(),
                ),
        ),
      );
    }

    testWidgets('1. Bejelentkezési folyamat mock módban', (tester) async {
      mockApi.setAuthenticated(false);
      await store.initialize();

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Bejelentkező oldal ellenőrzése
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('HUNOR USAR'), findsOneWidget);
      expect(find.text('Gyors belépés (Mock fiók)'), findsOneWidget);

      // Gyors belépés folyamat
      await store.signIn('mock@example.invalid', 'password');
      await tester.pumpAndSettle();

      // Sikeres bejelentkezés után a főoldal jelenik meg
      expect(store.isAuthenticated, isTrue);
      expect(find.text('HUNOR Mentőszervezet'), findsWidgets);
      expect(find.text('120 RC'), findsNothing);
    });

    testWidgets('2. Cross-tenant adatelkülönítés a felületen (HUNOR vs BMSZ)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await store.initialize();

      // Alapértelmezett szervezet: HUNOR
      expect(store.currentOrganization?.code, 'HUNOR');

      // Ellenőrizzük a naptárat a HUNOR kontextusában
      await tester.pumpWidget(createTestApp(home: const CalendarPage()));
      await tester.pumpAndSettle();

      // Csak a HUNOR esemény látható
      expect(find.text('HUNOR Tavaszi Gyakorlat'), findsOneWidget);
      expect(find.text('BMSZ Barlangi Kötélgyakorlat'), findsNothing);

      // Ellenőrizzük a riasztásokat a HUNOR kontextusában
      await tester.pumpWidget(createTestApp(home: const AlertsPage()));
      await tester.pumpAndSettle();

      // Csak a HUNOR riasztás látható
      expect(find.text('Földrengési Riasztás – Előkészület'), findsOneWidget);
      expect(find.text('BMSZ Barlangi Készenlét'), findsNothing);

      // Szervezetváltás BMSZ-re
      await store.switchOrganization(MockRescuePlatformApi.orgBId);
      expect(store.currentOrganization?.code, 'BMSZ');

      // Újraellenőrizzük a naptárat a BMSZ kontextusában
      await tester.pumpWidget(createTestApp(home: const CalendarPage()));
      await tester.pumpAndSettle();

      // Most már kizárólag a BMSZ esemény látható
      expect(find.text('BMSZ Barlangi Kötélgyakorlat'), findsOneWidget);
      expect(find.text('HUNOR Tavaszi Gyakorlat'), findsNothing);

      // Újraellenőrizzük a riasztásokat a BMSZ kontextusában
      await tester.pumpWidget(createTestApp(home: const AlertsPage()));
      await tester.pumpAndSettle();

      // Most már kizárólag a BMSZ riasztás látható
      expect(find.text('BMSZ Barlangi Készenlét'), findsOneWidget);
      expect(find.text('Földrengési Riasztás – Előkészület'), findsNothing);
    });

    testWidgets('3. Riasztási válaszadás folyamata', (tester) async {
      await store.initialize();

      await tester.pumpWidget(createTestApp(home: const AlertsPage()));
      await tester.pumpAndSettle();

      // Kattintás a riasztási kártyára a modális ablak megnyitásához
      await tester.tap(find.text('Földrengési Riasztás – Előkészület'));
      await tester.pumpAndSettle();

      expect(find.text('Elérhető vagyok'), findsOneWidget);
      expect(find.text('Nem vagyok elérhető'), findsOneWidget);

      // Válaszadás: "Elérhető vagyok"
      await tester.tap(find.text('Elérhető vagyok'));
      await tester.pumpAndSettle();

      // Ellenőrizzük, hogy a válasz rögzítésre került
      expect(store.alertResponses[MockRescuePlatformApi.mockAlertAId], 'available');
    });

    testWidgets('4. Kijelentkezéskor a szervezeti adatok és gyorsítótár ürítése', (tester) async {
      await store.initialize();
      expect(store.events.isNotEmpty, isTrue);
      expect(store.alerts.isNotEmpty, isTrue);

      await tester.pumpWidget(createTestApp(home: const ProfilePage()));
      await tester.pumpAndSettle();

      // Kijelentkezés gomb megnyomása
      await tester.tap(find.text('Kijelentkezés és gyorsítótár ürítése'));
      await tester.pumpAndSettle();

      // Az állapot kiürült, kijelentkezve
      expect(store.isAuthenticated, isFalse);
      expect(store.currentOrganization, isNull);
      expect(store.events, isEmpty);
      expect(store.alerts, isEmpty);
      expect(store.coinBalance, isNull);
    });
  });
}
