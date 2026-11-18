import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hunor_app/api/mock_rescue_platform_api.dart';
import 'package:hunor_app/models/excon_evaluation.dart';
import 'package:hunor_app/services/app_store.dart';
import 'package:hunor_app/views/excon_screen.dart';
import 'package:hunor_app/theme/hunor_theme.dart';

void main() {
  group('EXCON Értékelő Felület – Kategória Görgető és Nem Értékelem Opció', () {
    late MockRescuePlatformApi mockApi;
    late AppStore store;

    setUp(() {
      mockApi = MockRescuePlatformApi();
      store = AppStore(api: mockApi);
    });

    Widget createTestApp() {
      return ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: MaterialApp(
          theme: HunorTheme.dark,
          home: const Scaffold(body: ExconScreen()),
        ),
      );
    }

    test('ExconEvaluation modell támogatja a -1 pontszámot (Nem értékelem)', () {
      const eval = ExconEvaluation(
        evaluatorName: 'Teszt Értékelő',
        checkpointCode: '1.1',
        score: -1,
        comment: 'Nem releváns a jelenlegi fázisban',
      );

      expect(eval.score, -1);
      final json = eval.toJson();
      expect(json['score'], -1);

      final restored = ExconEvaluation.fromJson(json);
      expect(restored.score, -1);
      expect(restored.checkpointCode, '1.1');
    });

    testWidgets('ExconScreen megjeleníti a kategória görgetőt és a Nem értékelem gombot', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Kategória görgető ellenőrzése
      expect(find.text('Műveleti Kategória (Görgethető):'), findsOneWidget);
      expect(find.text('Mobilizáció'), findsOneWidget);
      expect(find.text('Koordináció'), findsOneWidget);
      expect(find.text('Műveleti Tervezés'), findsOneWidget);

      // Négy pontozó gomb megléte (2 pont, 1 pont, 0 pont, Nem értékelem)
      expect(find.text('2 PONT  ·  MEGFELELŐ / KIVÁLÓ'), findsOneWidget);
      expect(find.text('1 PONT  ·  RÉSZBEN MEGFELELŐ'), findsOneWidget);
      expect(find.text('0 PONT  ·  NEM MEGFELELŐ'), findsOneWidget);
      expect(find.text('NEM ÉRTÉKELEM  ·  NEM RELEVÁNS / N/A'), findsOneWidget);

      // Kategória váltás Koordinációra
      await tester.tap(find.text('Koordináció'));
      await tester.pumpAndSettle();

      // Nem értékelem kiválasztása
      await tester.tap(find.text('NEM ÉRTÉKELEM  ·  NEM RELEVÁNS / N/A'));
      await tester.pumpAndSettle();

      // Beküldés gomb megnyomása
      await tester.tap(find.text('BEKÜLDÉS'));
      await tester.pumpAndSettle();

      // Sikeres visszajelzés snackbar
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
