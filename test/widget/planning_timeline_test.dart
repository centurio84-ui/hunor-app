import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hunor_app/api/supabase_rescue_platform_api.dart';
import 'package:hunor_app/features/planning/exercise_planning_screen.dart';
import 'package:hunor_app/features/planning/planning_models.dart';
import 'package:hunor_app/features/planning/planning_timeline_wall.dart';
import 'package:hunor_app/models/organization.dart';
import 'package:hunor_app/services/app_store.dart';
import 'package:hunor_app/theme/hunor_theme.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Adds, copies, reorders and resizes independent timeline tracks',
      (tester) async {
    final api = _TimelineApi();
    await _openWall(tester, api);

    await _tap(
        tester, find.widgetWithText(FilledButton, 'Buborék az idővonalra'));
    await _enter(tester, 'Kezdés a STARTEX-től (óra)', '2');
    await _enter(tester, 'Időtartam (óra)', '0');
    await _tap(tester, find.widgetWithText(FilledButton, 'Hozzáadás'));
    expect(find.text('Az időtartam legyen nagyobb nullánál.'), findsOneWidget);
    await _enter(tester, 'Időtartam (óra)', '1,5');
    await _enter(tester, 'Megjegyzés', 'Kezdés az eligazítás után');
    await _tap(tester, find.widgetWithText(FilledButton, 'Hozzáadás'));

    final planned = find.byKey(const ValueKey('planned-block-1'));
    final actual = find.byKey(const ValueKey('actual-block-1'));
    expect(planned, findsOneWidget);
    expect(actual, findsNothing);
    expect(api.block?['sector_id'], 'sector-1');
    expect(api.block?['notes'], 'Kezdés az eligazítás után');
    expect(find.text('Tervezett ENDEX: +3,5 óra'), findsOneWidget);

    await _tap(tester, planned);
    await _tap(tester, find.widgetWithText(TextButton, 'Másolás Real-re'));
    expect(actual, findsOneWidget);
    expect(api.copyArguments?['p_overwrite'], isFalse);
    expect(ExerciseTimelineBlock.fromJson(api.block!).endVariance, 0);

    final oldPlannedWidth = tester.getSize(planned).width;
    final oldPlannedStart = tester.getTopLeft(planned).dx;
    await _tap(tester, planned);
    await _enter(tester, 'Kezdés a STARTEX-től (óra)', '1');
    await _enter(tester, 'Időtartam (óra)', '2');
    await _tap(tester, find.widgetWithText(FilledButton, 'Mentés'));
    expect(tester.getSize(planned).width, greaterThan(oldPlannedWidth));
    expect(tester.getTopLeft(planned).dx, lessThan(oldPlannedStart));
    expect(api.lastPatch?['planned_start_hour'], 1);
    expect(api.lastPatch?.containsKey('actual_start_hour'), isFalse);
    expect(api.block?['actual_start_hour'], 2);
    expect(api.block?['actual_duration_hours'], 1.5);

    await _tap(tester, actual);
    await _enter(tester, 'Kezdés a STARTEX-től (óra)', '3');
    await _enter(tester, 'Időtartam (óra)', '2,5');
    await _tap(tester, find.byType(DropdownButtonFormField<TimelineStatus>));
    await _tap(tester, find.text('Késik').last);
    await _tap(tester, find.widgetWithText(FilledButton, 'Mentés'));
    expect(api.lastPatch?['status'], 'delayed');
    expect(api.lastPatch?.containsKey('planned_duration_hours'), isFalse);
    expect(find.textContaining('2,5 óra késés'), findsOneWidget);
    expect(ExerciseTimelineBlock.fromJson(api.block!).endVariance, 2.5);

    await _tap(tester, planned);
    await _tap(tester, find.widgetWithText(TextButton, 'Másolás Real-re'));
    await _tap(tester, find.widgetWithText(TextButton, 'Mégse'));
    expect(api.block?['actual_start_hour'], 3);
    await _tap(tester, planned);
    await _tap(tester, find.widgetWithText(TextButton, 'Másolás Real-re'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Felülírás'));
    expect(api.copyArguments?['p_overwrite'], isTrue);
    expect(api.block?['status'], 'delayed');
    expect(ExerciseTimelineBlock.fromJson(api.block!).endVariance, 0);

    await _tap(
        tester, find.widgetWithText(DropdownButton<String>, 'Minden pálya'));
    await _tap(tester, find.text('Közös célok').last);
    expect(planned, findsNothing);
    await _tap(
        tester, find.widgetWithText(DropdownButton<String>, 'Közös célok'));
    await _tap(tester, find.text('ROM 1').last);
    expect(planned, findsOneWidget);

    await _tap(tester, planned);
    await _tap(tester, find.widgetWithText(TextButton, 'Blokk törlése'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Törlés'));
    expect(api.block, isNull);
    expect(planned, findsNothing);
    expect(actual, findsNothing);
  });

  testWidgets('A narrow 5m wall scrolls to blocks beyond the viewport',
      (tester) async {
    final api = _TimelineApi()
      ..block = {
        'id': 'block-1',
        'exercise_id': 'exercise-1',
        'sector_id': 'sector-1',
        'bubble_id': 'bubble-1',
        'planned_start_hour': 11,
        'planned_duration_hours': 2,
        'actual_start_hour': 12,
        'actual_duration_hours': 2,
        'is_copied_to_actual': true,
        'status': 'in_progress',
        'notes': '',
        'created_at': _TimelineApi._timestamp,
        'updated_at': _TimelineApi._timestamp,
      };
    await _openWall(tester, api, size: const Size(360, 700));
    final actual = find.byKey(const ValueKey('actual-block-1'));
    final planned = find.byKey(const ValueKey('planned-block-1'));
    await _tap(
        tester, find.widgetWithText(DropdownButton<String>, 'Minden pálya'));
    await _tap(tester, find.text('ROM 1').last);
    expect(tester.getTopLeft(actual).dx,
        greaterThan(tester.getTopLeft(planned).dx));
    await _tap(tester, actual);
    expect(find.text('Real időzítés'), findsOneWidget);
  });

  testWidgets('Shows migration fallback and returns to the board',
      (tester) async {
    final api = _TimelineApi(missingTable: true);
    await _openWall(tester, api, size: const Size(360, 700));
    expect(find.textContaining('az adatbázis frissítése után'), findsOneWidget);
    await _tap(
        tester, find.widgetWithText(ChoiceChip, 'Tervezőasztal & Pályák'));
    expect(find.text('Közös Célok Asztala'), findsOneWidget);
    expect(find.byType(PlanningTimelineWall), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openWall(
  WidgetTester tester,
  _TimelineApi api, {
  Size size = const Size(1280, 950),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final client = (await tester.runAsync(() async => SupabaseClient(
        'https://planning.example.invalid',
        'test-key',
        httpClient: MockClient(api.respond),
      )))!;
  addTearDown(() async => tester.runAsync(client.dispose));
  final store = AppStore(api: SupabaseRescuePlatformApi(client: client))
    ..initialized = true
    ..isAuthenticated = true
    ..currentUserRole = MemberRole.admin
    ..currentOrganization =
        const Organization(id: 'org-hunor', code: 'HUNOR', name: 'HUNOR');
  addTearDown(store.dispose);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
        theme: HunorTheme.dark, home: const ExercisePlanningScreen()),
  ));
  await tester.pumpAndSettle();
  await _tap(tester, find.byType(DropdownButton<String>));
  await _tap(tester, find.text('Próbagyakorlat').last);
  await _tap(
      tester, find.widgetWithText(ChoiceChip, '5m fal · Tervezett / Real'));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

class _TimelineApi {
  _TimelineApi({this.missingTable = false});

  static const _timestamp = '2026-11-23T12:00:00Z';
  final bool missingTable;
  Map<String, dynamic>? block;
  Map<String, dynamic>? lastPatch;
  Map<String, dynamic>? copyArguments;

  Future<http.Response> respond(http.Request request) async {
    http.Response json(Object data, {int status = 200}) => http.Response(
          jsonEncode(data),
          status,
          request: request,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    switch ((request.method, request.url.pathSegments.last)) {
      case ('GET', 'exercises'):
        return json([
          {
            'id': 'exercise-1',
            'organization_id': 'org-hunor',
            'title': 'Próbagyakorlat',
            'created_at': _timestamp
          },
        ]);
      case ('GET', 'exercise_sectors'):
        return json([
          {
            'id': 'sector-1',
            'exercise_id': 'exercise-1',
            'name': 'ROM 1',
            'number': 1
          },
        ]);
      case ('GET', 'exercise_bubbles'):
        return json([
          {
            'id': 'bubble-1',
            'exercise_id': 'exercise-1',
            'sector_id': 'sector-1',
            'bubble_type': 'medical',
            'title': 'Ellátópont',
            'estimated_hours': 1.5,
            'specs': {'patient_count': 3}
          },
        ]);
      case ('GET', 'insarag_checkpoint_catalog'):
        return json([]);
      case ('GET', 'exercise_timeline_blocks'):
        if (missingTable) {
          return json({'code': 'PGRST205', 'message': 'Missing timeline table'},
              status: 404);
        }
        return json([if (block != null) block]);
      case ('POST', 'exercise_timeline_blocks'):
        block = {
          ...jsonDecode(request.body) as Map<String, dynamic>,
          'id': 'block-1',
          'is_copied_to_actual': false,
          'actual_start_hour': null,
          'actual_duration_hours': null,
          'status': 'planned',
          'created_at': _timestamp,
          'updated_at': _timestamp,
        };
        expect(block?['exercise_id'], 'exercise-1');
        expect(block?['bubble_id'], 'bubble-1');
        return json(block!);
      case ('PATCH', 'exercise_timeline_blocks'):
        expect(request.url.queryParameters['exercise_id'], 'eq.exercise-1');
        expect(request.url.queryParameters['id'], 'eq.block-1');
        lastPatch = jsonDecode(request.body) as Map<String, dynamic>;
        block!.addAll(lastPatch!);
        return json(block!);
      case ('DELETE', 'exercise_timeline_blocks'):
        expect(request.url.queryParameters['exercise_id'], 'eq.exercise-1');
        expect(request.url.queryParameters['id'], 'eq.block-1');
        block = null;
        return json({'id': 'block-1'});
      case ('POST', 'copy_planning_block_to_actual'):
        copyArguments = jsonDecode(request.body) as Map<String, dynamic>;
        expect(copyArguments?['p_exercise_id'], 'exercise-1');
        expect(copyArguments?['p_block_id'], 'block-1');
        final saved = block!;
        saved['actual_start_hour'] = saved['planned_start_hour'];
        saved['actual_duration_hours'] = saved['planned_duration_hours'];
        saved['is_copied_to_actual'] = true;
        return json(saved);
      default:
        throw StateError('Unexpected request ${request.method} ${request.url}');
    }
  }
}
