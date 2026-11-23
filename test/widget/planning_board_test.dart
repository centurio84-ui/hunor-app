import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hunor_app/features/planning/planning_board.dart';
import 'package:hunor_app/features/planning/planning_models.dart';
import 'package:hunor_app/features/planning/planning_repository.dart';
import 'package:hunor_app/theme/hunor_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _exercise = 'exercise-1';
const _checkpointTitle = 'Átkutatás és jelölés';
const _shared = ValueKey('shared-goals');
const _sector = ValueKey('sector-1');

void main() {
  testWidgets('Filters catalog and persists tap, drag and accessible moves', (
    tester,
  ) async {
    final api = _PlanningApi();
    await _showBoard(tester, api);

    final search = find.byType(TextField);
    for (final term in ['ASR-01', 'átkutatás', 'mapping']) {
      await tester.enterText(search, term);
      await tester.pumpAndSettle();
      expect(find.text(_checkpointTitle), findsOneWidget, reason: term);
    }
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'ASR'));
    await tester.pumpAndSettle();
    expect(find.text('Emelés'), findsNothing);

    await tester.tap(find.text(_checkpointTitle));
    await tester.pumpAndSettle();
    expect(api.bubbles.single['checkpoint_id'], 'checkpoint-1');
    expect(api.bubbles.single['sector_id'], isNull);
    expect(api.bubbles.single['estimated_hours'], 1.5);

    final checkpoint = find.byWidgetPredicate(
      (widget) => widget is Draggable<InsaragCheckpoint>,
    );
    await _dragTo(tester, checkpoint, find.byKey(_shared));
    expect(api.bubbles, hasLength(2));

    final bubble = find.byKey(const ValueKey('bubble-1'));
    await _dragTo(tester, bubble, find.byKey(_sector));
    expect(api.bubbles.first['sector_id'], 'sector-1');
    expect(find.text('1 buborék · 1,5 óra'), findsOneWidget);
    expect(api.lastPatch, {'sector_id': 'sector-1'});

    await _dragTo(tester, bubble, find.byKey(_shared));
    expect(api.bubbles.first['sector_id'], isNull);

    final assignment = find.descendant(
      of: bubble,
      matching: find.byTooltip('Buborék áthelyezése'),
    );
    await tester.tap(assignment);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'ROM 1'));
    await tester.pumpAndSettle();
    expect(api.bubbles.first['sector_id'], 'sector-1');

    await tester.tap(assignment);
    await tester.pumpAndSettle();
    await tester
        .tap(find.widgetWithText(PopupMenuItem<String>, 'Közös Célok Asztala'));
    await tester.pumpAndSettle();
    expect(api.bubbles.first['sector_id'], isNull);
  });

  testWidgets('Creates, edits and deletes a custom goal with an empty catalog',
      (
    tester,
  ) async {
    final api = _PlanningApi(emptyCatalog: true);
    await _showBoard(tester, api);
    expect(find.textContaining('A katalógus még üres'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Egyedi cél buborék'));
    await tester.pumpAndSettle();
    await _enter(tester, 'Cím', 'Egyedi mentési feladat');
    await _enter(tester, 'Becsült idő (óra)', '1,25');
    await _enter(tester, 'Falvastagság (cm)', '25');
    await _enter(tester, 'Tájolás', 'Függőleges');
    await _enter(tester, 'Dúcolás típusa', 'Fa');
    await _enter(tester, 'Megjegyzések', 'Gyakorló feladat');
    await tester.tap(find.widgetWithText(FilledButton, 'Létrehozás'));
    await tester.pumpAndSettle();

    expect(api.bubbles.single['bubble_type'], 'custom');
    expect(api.bubbles.single['estimated_hours'], 1.25);
    expect(api.bubbles.single['specs'], {
      'wall_thickness_cm': 25,
      'orientation': 'Függőleges',
      'shoring_type': 'Fa',
      'notes': 'Gyakorló feladat',
    });

    await tester.tap(find.text('Egyedi mentési feladat'));
    await tester.pumpAndSettle();
    await _enter(tester, 'Cím', 'Módosított cél');
    await _enter(tester, 'Becsült idő (óra)', '-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Mentés'));
    await tester.pumpAndSettle();
    expect(find.text('Adj meg egy nem negatív számot.'), findsOneWidget);
    await _enter(tester, 'Becsült idő (óra)', '');
    await _enter(tester, 'Megjegyzések', '');
    await tester.tap(find.widgetWithText(FilledButton, 'Mentés'));
    await tester.pumpAndSettle();
    expect(api.bubbles.single['estimated_hours'], isNull);
    expect((api.bubbles.single['specs'] as Map).containsKey('notes'), isFalse);
    expect(api.lastPatch!.containsKey('sector_id'), isFalse);

    await tester.tap(find.text('Módosított cél'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Törlés'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Törlés'));
    await tester.pumpAndSettle();
    expect(api.bubbles, isEmpty);
    expect(find.text('Módosított cél'), findsNothing);
  });

  testWidgets('Creates, edits, filters and assigns discipline bubbles',
      (tester) async {
    final api = _PlanningApi(emptyCatalog: true);
    await _showBoard(tester, api);
    final editor = find.byType(AlertDialog);

    Future<void> open() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Új szakági buborék'));
      await tester.pumpAndSettle();
    }

    Future<void> choose(Finder field, String option) async {
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }

    Future<void> create() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Létrehozás'));
      await tester.pumpAndSettle();
    }

    await open();
    await _enter(tester, 'Cím', 'Ellátópont');
    await _enter(tester, 'Sérülés vagy klinikai helyzet', 'Végtagsérülés');
    await _enter(tester, 'Becsült betegszám', '3');
    await _enter(
        tester, 'Kimentés, ellátás és kiürítés', 'Átadás az ellátóponton');
    await _enter(tester, 'Becsült idő (óra)', '2');
    await create();
    expect(api.bubbles.first['bubble_type'], 'medical');
    expect(api.bubbles.first['specs'], {
      'clinical_scenario': 'Végtagsérülés',
      'patient_count': 3,
      'medical_notes': 'Átadás az ellátóponton',
    });

    await open();
    await choose(
        find.descendant(
            of: editor,
            matching: find.byType(DropdownButtonFormField<BubbleDiscipline>)),
        'UCC / törzs');
    await _enter(tester, 'Cím', 'Törzsgyakorlat');
    await _enter(tester, 'Koordinációs vagy törzsszerep / csapat', 'UCC');
    await _enter(tester, 'Szituációindító esemény', 'Beérkező jelentés');
    await create();
    expect(api.bubbles[1]['bubble_type'], 'ucc');
    expect(api.bubbles[1]['specs'], {
      'coordination_role': 'UCC',
      'inject_trigger': 'Beérkező jelentés',
    });

    await open();
    await choose(
        find.descendant(
            of: editor,
            matching: find.byType(DropdownButtonFormField<BubbleDiscipline>)),
        'Sajtó / VIP / LEMA');
    await _enter(tester, 'Cím', 'Tájékoztató');
    await choose(find.byKey(const ValueKey('stakeholder_type')), 'LEMA');
    await _enter(
        tester, 'Tájékoztatás, kíséret, média és belépés', 'Belépés a főkapun');
    await create();
    expect(api.bubbles[2]['bubble_type'], 'press_vip');
    expect(api.bubbles[2]['specs'], {
      'stakeholder_type': 'LEMA',
      'protocol_notes': 'Belépés a főkapun',
    });

    await tester.tap(find.text('Ellátópont'));
    await tester.pumpAndSettle();
    await _enter(tester, 'Becsült betegszám', '-2');
    await tester.tap(find.widgetWithText(FilledButton, 'Mentés'));
    await tester.pumpAndSettle();
    expect(find.text('Adj meg egy nem negatív egész számot.'), findsOneWidget);
    await _enter(tester, 'Becsült betegszám', '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Mentés'));
    await tester.pumpAndSettle();
    expect((api.bubbles.first['specs'] as Map)['patient_count'], 5);
    expect(api.lastPatch!.containsKey('bubble_type'), isFalse);

    await choose(find.byTooltip('Szűrés szakág szerint'), 'Egészségügy / EÜ');
    expect(find.text('Törzsgyakorlat'), findsNothing);
    expect(find.text('Tájékoztató'), findsNothing);
    final card = find.byKey(const ValueKey('bubble-1'));
    await _dragTo(tester, card, find.byKey(_sector));
    expect(api.bubbles.first['sector_id'], 'sector-1');
    expect(find.text('1 buborék · 2 óra'), findsOneWidget);

    final assignment = find.descendant(
        of: card, matching: find.byTooltip('Buborék áthelyezése'));
    await choose(assignment, 'Közös Célok Asztala');
    expect(api.bubbles.first['sector_id'], isNull);
  });

  testWidgets('The catalog and board fit a narrow screen', (tester) async {
    await _showBoard(tester, _PlanningApi(), size: const Size(360, 640));
    expect(find.text('INSARAG ellenőrzőpontok'), findsOneWidget);
    expect(find.text('Közös Célok Asztala'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Adds the next sector and keeps the board after a failed write', (
    tester,
  ) async {
    final api = _PlanningApi();
    await _showBoard(tester, api);
    api.rejectNextWrite = true;

    await tester.tap(find.text(_checkpointTitle));
    await tester.pumpAndSettle();
    expect(api.bubbles, isEmpty);
    expect(
        find.text('Az ellenőrzőpont hozzáadása nem sikerült.'), findsOneWidget);

    await tester.tap(find.text(_checkpointTitle));
    await tester.pumpAndSettle();
    expect(api.bubbles, hasLength(1));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Új pálya'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Létrehozás'));
    await tester.pumpAndSettle();
    expect(find.text('ROM 2'), findsOneWidget);
    expect(api.sectors, hasLength(2));
  });
}

Future<void> _showBoard(
  WidgetTester tester,
  _PlanningApi api, {
  Size size = const Size(1280, 950),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final client = (await tester.runAsync(() async => SupabaseClient(
        'https://planning.example.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          final response = await api.respond(request);
          return http.Response.bytes(
            response.bodyBytes,
            response.statusCode,
            headers: response.headers,
            request: request,
          );
        }),
      )))!;
  addTearDown(() async {
    await tester.runAsync(client.dispose);
  });
  await tester.pumpWidget(MaterialApp(
    theme: HunorTheme.dark,
    home: Scaffold(
        body: PlanningBoard(
      exerciseId: _exercise,
      repository: PlanningRepository(client, organizationId: 'org-hunor'),
    )),
  ));
  await tester.pumpAndSettle();
}

Future<void> _dragTo(WidgetTester tester, Finder source, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(source));
  await gesture.moveBy(const Offset(20, 0));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

class _PlanningApi {
  _PlanningApi({this.emptyCatalog = false});

  final bool emptyCatalog;
  final bubbles = <Map<String, dynamic>>[];
  final sectors = <Map<String, dynamic>>[
    {'id': 'sector-1', 'name': 'ROM 1', 'number': 1, 'exercise_id': _exercise},
  ];
  Map<String, dynamic>? lastPatch;
  bool rejectNextWrite = false;

  Future<http.Response> respond(http.Request request) async {
    final table = request.url.pathSegments.last;
    if (rejectNextWrite && request.method != 'GET') {
      rejectNextWrite = false;
      return _json({'message': 'Write rejected'}, status: 403);
    }

    switch ((request.method, table)) {
      case ('GET', 'insarag_checkpoint_catalog'):
        return _json(emptyCatalog
            ? []
            : [
                {
                  'id': 'checkpoint-1',
                  'code': 'ASR-01',
                  'title_hu': _checkpointTitle,
                  'title_en': 'Search and mapping',
                  'category': 'ASR',
                  'sort_order': 1,
                  'default_duration_hours': 1.5,
                },
                {
                  'id': 'checkpoint-2',
                  'code': 'R-02',
                  'title_hu': 'Emelés',
                  'category': 'RESCUE',
                  'sort_order': 2,
                },
              ]);
      case ('GET', 'exercise_sectors'):
        return _json(sectors);
      case ('GET', 'exercise_bubbles'):
        return _json(bubbles);
      case ('POST', 'exercise_bubbles'):
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['exercise_id'], _exercise);
        final bubble = {
          ...body,
          'id': 'bubble-${bubbles.length + 1}',
          'bubble_type': body['bubble_type'] ??
              (body['checkpoint_id'] == null ? 'custom' : 'checkpoint'),
        };
        bubbles.add(bubble);
        return _json(bubble);
      case ('PATCH', 'exercise_bubbles'):
        lastPatch = jsonDecode(request.body) as Map<String, dynamic>;
        final row = _bubbleFor(request)..addAll(lastPatch!);
        return _json(row);
      case ('DELETE', 'exercise_bubbles'):
        final row = _bubbleFor(request);
        bubbles.remove(row);
        return _json({'id': row['id']});
      case ('POST', 'create_planning_sector'):
        expect(jsonDecode(request.body), {'p_exercise_id': _exercise});
        final number = sectors.length + 1;
        final sector = {
          'id': 'sector-$number',
          'name': 'ROM $number',
          'number': number,
          'exercise_id': _exercise,
        };
        sectors.add(sector);
        return _json(sector);
      default:
        throw StateError('Unexpected request ${request.method} ${request.url}');
    }
  }

  Map<String, dynamic> _bubbleFor(http.Request request) {
    expect(request.url.queryParameters['exercise_id'], 'eq.$_exercise');
    return bubbles.singleWhere(
        (row) => request.url.queryParameters['id'] == 'eq.${row['id']}');
  }

  http.Response _json(Object data, {int status = 200}) =>
      http.Response(jsonEncode(data), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
}
