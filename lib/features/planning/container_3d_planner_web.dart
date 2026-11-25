import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'planning_models.dart';
import 'planning_repository.dart';

@JS('document.createElement')
external _DomElement _createElement(String tagName);

@JS('window')
external _DomWindow get _window;

@JS('JSON.stringify')
external String? _jsonStringify(JSAny? value);

extension type _DomStyle(JSObject _) implements JSObject {
  external set width(String value);
  external set height(String value);
  external set border(String value);
  external set display(String value);
  external set overflow(String value);
}

extension type _MessageEvent(JSObject _) implements JSObject {
  external JSAny? get data;
}

extension type _DomWindow(JSObject _) implements JSObject {
  external void postMessage(JSAny? message, String targetOrigin);
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _DomElement(JSObject _) implements JSObject {
  external set src(String value);
  external _DomStyle get style;
  external _DomWindow? get contentWindow;
  external void setAttribute(String name, String value);
  external void addEventListener(String type, JSFunction listener);
}

int _nextPlannerViewId = 0;

/// Built-in 21-item INSARAG Checkpoint Catalog fallback (if DB rows are unavailable).
const List<Map<String, dynamic>> _fallback21Catalog = [
  {'id': 'HUNOR-ASR-1', 'code': 'HUNOR-ASR-1', 'category': 'ASR', 'titleHu': 'ASR 1 – Nagy területű felmérés', 'sortOrder': 100},
  {'id': 'HUNOR-ASR-2', 'code': 'HUNOR-ASR-2', 'category': 'ASR', 'titleHu': 'ASR 2 – Kárhelyek felmérése és rangsorolása', 'sortOrder': 110},
  {'id': 'HUNOR-ASR-3', 'code': 'HUNOR-ASR-3', 'category': 'ASR', 'titleHu': 'ASR 3 – Gyors kutatás-mentés', 'sortOrder': 120},
  {'id': 'HUNOR-ASR-4', 'code': 'HUNOR-ASR-4', 'category': 'ASR', 'titleHu': 'ASR 4 – Teljes körű kutatás-mentés', 'sortOrder': 130},
  {'id': 'HUNOR-ASR-5', 'code': 'HUNOR-ASR-5', 'category': 'ASR', 'titleHu': 'ASR 5 – Teljes lefedettségű kutatás és kiemelés', 'sortOrder': 140},
  {'id': 'HUNOR-SEARCH-01', 'code': 'HUNOR-SEARCH-01', 'category': 'SEARCH', 'titleHu': 'Személyes kutatás és visszajelzés', 'sortOrder': 200},
  {'id': 'HUNOR-SEARCH-02', 'code': 'HUNOR-SEARCH-02', 'category': 'SEARCH', 'titleHu': 'Mentőkutyás kutatás', 'sortOrder': 210},
  {'id': 'HUNOR-SEARCH-03', 'code': 'HUNOR-SEARCH-03', 'category': 'SEARCH', 'titleHu': 'Műszeres vizuális kutatás', 'sortOrder': 220},
  {'id': 'HUNOR-SEARCH-04', 'code': 'HUNOR-SEARCH-04', 'category': 'SEARCH', 'titleHu': 'Műszeres akusztikus kutatás', 'sortOrder': 230},
  {'id': 'HUNOR-RESCUE-01', 'code': 'HUNOR-RESCUE-01', 'category': 'RESCUE', 'titleHu': 'Szerkezeti stabilizálás és dúcolás (Shoring)', 'sortOrder': 300},
  {'id': 'HUNOR-RESCUE-02', 'code': 'HUNOR-RESCUE-02', 'category': 'RESCUE', 'titleHu': 'Hozzáférési nyílás kialakítása vasbetonban (Breaching)', 'sortOrder': 310},
  {'id': 'HUNOR-RESCUE-03', 'code': 'HUNOR-RESCUE-03', 'category': 'RESCUE', 'titleHu': 'Teher emelése és mozgatása (Lifting & Moving)', 'sortOrder': 320},
  {'id': 'HUNOR-RESCUE-04', 'code': 'HUNOR-RESCUE-04', 'category': 'RESCUE', 'titleHu': 'Sérült kimentése kötéltechnikával', 'sortOrder': 330},
  {'id': 'HUNOR-MEDICAL-01', 'code': 'HUNOR-MEDICAL-01', 'category': 'MEDICAL', 'titleHu': 'Sérültvizsgálat és triázs', 'sortOrder': 400},
  {'id': 'HUNOR-MEDICAL-02', 'code': 'HUNOR-MEDICAL-02', 'category': 'MEDICAL', 'titleHu': 'Egészségügyi ellátás szűk térben', 'sortOrder': 410},
  {'id': 'HUNOR-MEDICAL-03', 'code': 'HUNOR-MEDICAL-03', 'category': 'MEDICAL', 'titleHu': 'Sérült kiürítése és átadása', 'sortOrder': 420},
  {'id': 'HUNOR-MEDICAL-04', 'code': 'HUNOR-MEDICAL-04', 'category': 'MEDICAL', 'titleHu': 'Csapattag egészségügyi kiürítésének gyakorlása', 'sortOrder': 430},
  {'id': 'HUNOR-COORD-01', 'code': 'HUNOR-COORD-01', 'category': 'COORDINATION', 'titleHu': 'Fogadási és indulási központ (RDC)', 'sortOrder': 500},
  {'id': 'HUNOR-COORD-02', 'code': 'HUNOR-COORD-02', 'category': 'COORDINATION', 'titleHu': 'UCC-koordináció és feladatkiosztás', 'sortOrder': 510},
  {'id': 'HUNOR-COORD-03', 'code': 'HUNOR-COORD-03', 'category': 'COORDINATION', 'titleHu': 'Kárhelyjelölés és műveleti jelentés', 'sortOrder': 520},
  {'id': 'HUNOR-COORD-04', 'code': 'HUNOR-COORD-04', 'category': 'COORDINATION', 'titleHu': 'Egyeztetés a helyi hatósággal (LEMA)', 'sortOrder': 530},
];

class Container3DPlannerTabImpl extends StatefulWidget {
  const Container3DPlannerTabImpl({
    super.key,
    this.exerciseId,
    this.exerciseTitle,
    this.repository,
    this.onSavingChanged,
  });

  final String? exerciseId;
  final String? exerciseTitle;
  final PlanningRepository? repository;
  final ValueChanged<bool>? onSavingChanged;

  @override
  State<Container3DPlannerTabImpl> createState() =>
      _Container3DPlannerTabImplState();
}

class _Container3DPlannerTabImplState extends State<Container3DPlannerTabImpl> {
  late final String _viewType;
  _DomElement? _iframe;
  JSFunction? _messageListener;
  bool _iframeReady = false;
  bool _syncInFlight = false;
  Timer? _debounceSaveTimer;
  Map<String, dynamic>? _pendingSceneJson;

  List<InsaragCheckpoint> _allCatalog = [];

  @override
  void initState() {
    super.initState();
    _viewType = 'hunor-3d-container-planner-${++_nextPlannerViewId}';

    _messageListener = ((JSAny? rawEvent) {
      if (rawEvent == null) return;
      _handleWindowMessage(_MessageEvent(rawEvent as JSObject));
    }).toJS;
    _window.addEventListener('message', _messageListener!);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = _createElement('iframe')
        ..src = '3d_container_planner.html?v=3'
        ..setAttribute('allow', 'accelerometer; gyroscope')
        ..setAttribute('title', '3D Konténerváz tervező');
      iframe.style
        ..width = '100%'
        ..height = '100%'
        ..border = 'none'
        ..display = 'block'
        ..overflow = 'hidden';
      iframe.addEventListener(
        'load',
        ((JSAny? _) {
          _iframeReady = true;
          _pushPlanningContextToIframe();
        }).toJS,
      );
      _iframe = iframe;
      return iframe;
    });
  }

  @override
  void didUpdateWidget(covariant Container3DPlannerTabImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId && _iframeReady) {
      _pushPlanningContextToIframe();
    }
  }

  void _postToIframe(Map<String, dynamic> message) {
    final win = _iframe?.contentWindow;
    if (win == null) return;
    try {
      // Pass JSON string inside a simple envelope to avoid deep jsify pitfalls
      final envelope = <String, Object?>{
        'type': message['type'],
        'json': jsonEncode(message),
      }.jsify();
      win.postMessage(envelope, '*');
    } catch (_) {}
  }

  void _handleWindowMessage(_MessageEvent event) {
    try {
      final rawStr = _jsonStringify(event.data);
      if (rawStr == null || rawStr.isEmpty) return;
      final decoded = jsonDecode(rawStr);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      final type = map['type']?.toString() ?? '';

      if (type == 'PLANNER_3D_READY' || type == 'PLANNER_3D_REQUEST_RELOAD') {
        _iframeReady = true;
        _pushPlanningContextToIframe();
      } else if (type == 'PLANNER_3D_SAVE_SCENE') {
        final rawScene = map['scene'];
        if (rawScene is Map) {
          _scheduleSceneSync(
            Map<String, dynamic>.from(rawScene),
            immediate: map['immediate'] == true,
          );
        }
      }
    } catch (_) {}
  }

  String _triageFromVictim(ExerciseBubble b) {
    final explicit = b.specs['triage']?.toString().toLowerCase() ?? '';
    if (explicit == 'red' ||
        explicit == 'yellow' ||
        explicit == 'green' ||
        explicit == 'black') {
      return explicit;
    }
    final inj =
        '${b.title} ${b.specs['injury_type'] ?? ''}'.toLowerCase();
    if (inj.contains('elhunyt') || inj.contains('black')) return 'black';
    if (inj.contains('crush') ||
        inj.contains('amput') ||
        inj.contains('eszméletlen') ||
        inj.contains('polytrauma') ||
        inj.contains('vérzés') ||
        inj.contains('füst') ||
        inj.contains('légúti')) {
      return 'red';
    }
    if (inj.contains('törés') || inj.contains('égés') || inj.contains('k9')) {
      return 'yellow';
    }
    return 'green';
  }

  String _formatOffsetLabel(double hours) {
    final totalMin = (hours * 60).round();
    final hh = (totalMin ~/ 60).toString().padLeft(2, '0');
    final mm = (totalMin % 60).toString().padLeft(2, '0');
    return 'T+$hh:$mm';
  }

  Future<void> _pushPlanningContextToIframe() async {
    final repo = widget.repository;
    final exerciseId = widget.exerciseId;

    if (repo == null || exerciseId == null) {
      _postToIframe({
        'type': 'INIT_PLANNING_CONTEXT',
        'hasExercise': false,
        'exerciseId': null,
        'exerciseTitle': null,
        'catalog21': _fallback21Catalog,
        'sectors': const [],
        'casualties': const [],
        'timelineEvents': const [],
        'scene': null,
      });
      return;
    }

    try {
      final results = await Future.wait([
        repo.fetchAllCheckpointsFor3D(),
        repo.fetchExerciseDetails(exerciseId),
        repo.fetchExerciseScene3D(exerciseId),
        repo.fetchTimeline(exerciseId).catchError((_) => <ExerciseTimelineBlock>[]),
      ]);

      final allCp = results[0] as List<InsaragCheckpoint>;
      _allCatalog = allCp;
      final details = results[1] as ExerciseDetails;
      final scene = results[2] as ExerciseScene3D;
      final timeline = results[3] as List<ExerciseTimelineBlock>;

      // Build the 21-item INSARAG catalog (HUNOR-* items) + key 14.8–14.11 operational items
      final hunor21 = allCp
          .where((c) => (c.code ?? '').startsWith('HUNOR-'))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      // Also expose specific 14.9 / 14.10 / 14.11 items if present, after the 21 core items
      final extra14 = allCp
          .where((c) =>
              (c.code ?? '').startsWith('INSARAG-14.8') ||
              (c.code ?? '').startsWith('INSARAG-14.9') ||
              (c.code ?? '').startsWith('INSARAG-14.10') ||
              (c.code ?? '').startsWith('INSARAG-14.11') ||
              (c.code ?? '').startsWith('INSARAG-14.12') ||
              (c.code ?? '').startsWith('INSARAG-14.13'))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final List<Map<String, dynamic>> catalogList = hunor21.isNotEmpty
          ? [
              for (final c in hunor21)
                {
                  ...c.toJson(),
                  'group': '21 tételes INSARAG alap-katalógus',
                },
              for (final c in extra14)
                {
                  ...c.toJson(),
                  'group': '14. fejezet – Részletes műszaki cikkek',
                },
            ]
          : _fallback21Catalog;

      final bubbleById = {for (final b in details.bubbles) b.id: b};
      final timelineByBubbleId = {
        for (final blk in timeline) blk.bubbleId: blk,
      };

      // Extract casualty records from /planning (medical discipline bubbles)
      final medicalBubbles = details.bubbles
          .where((b) => b.discipline == BubbleDiscipline.medical)
          .toList();

      final casualties = <Map<String, dynamic>>[];
      var sIndex = 1;
      for (final b in medicalBubbles) {
        final code =
            'S-${sIndex.toString().padLeft(2, '0')}';
        sIndex++;
        final blk = timelineByBubbleId[b.id];
        casualties.add({
          'casualtyId': b.id,
          'code': code,
          'title': b.title,
          'injuryType': (b.specs['injury_type'] ?? '').toString(),
          'careNotes': (b.specs['care_notes'] ?? '').toString(),
          'patientCount': (b.specs['patient_count'] as num?)?.toInt() ?? 1,
          'triage': _triageFromVictim(b),
          'sectorId': b.sectorId,
          'plannedTimeLabel':
              blk != null ? _formatOffsetLabel(blk.planned.start) : null,
          'placed3d': b.specs['placed_3d'] == true,
          'container3dId': b.specs['container_3d_id'],
          'localPos3d': b.specs['local_pos_3d'],
        });
      }

      final timelineEvents = <Map<String, dynamic>>[
        for (final blk in timeline)
          {
            'id': blk.id,
            'bubbleId': blk.bubbleId,
            'title': bubbleById[blk.bubbleId]?.title ?? 'Idővonal esemény',
            'startHour': blk.planned.start,
            'durationHours': blk.planned.duration,
            'timeLabel': _formatOffsetLabel(blk.planned.start),
          },
      ];

      _postToIframe({
        'type': 'INIT_PLANNING_CONTEXT',
        'hasExercise': true,
        'exerciseId': exerciseId,
        'exerciseTitle': widget.exerciseTitle ?? 'Kiválasztott gyakorlat',
        'catalog21': catalogList,
        'sectors': [
          for (final s in details.sectors)
            {
              'id': s.id,
              'name': s.name,
              'number': s.number,
              'icmsName': s.icmsName,
            },
        ],
        'casualties': casualties,
        'timelineEvents': timelineEvents,
        'scene': scene.isEmpty ? null : scene.toJson(),
      });
    } catch (_) {}
  }

  void _scheduleSceneSync(
    Map<String, dynamic> sceneJson, {
    bool immediate = false,
  }) {
    _pendingSceneJson = sceneJson;
    _debounceSaveTimer?.cancel();
    if (immediate) {
      _flushSceneSync();
    } else {
      _debounceSaveTimer = Timer(
        const Duration(milliseconds: 650),
        _flushSceneSync,
      );
    }
  }

  InsaragCheckpoint? _findCatalogItem(String? idOrCode) {
    if (idOrCode == null || idOrCode.isEmpty) return null;
    for (final c in _allCatalog) {
      if (c.id == idOrCode || c.code == idOrCode) return c;
    }
    return null;
  }

  String _obstacleTitleHu(Obstacle3D obs, String containerLabel) {
    final base = switch (obs.type) {
      'shoring_zone' => 'Dúcolási / megtámasztási zóna',
      'lifting_concrete' => 'Emelendő betonelem (Lifting & Moving)',
      'wood_beam_30x30x100' => '30×30×100cm fagerenda áthatolás',
      'breach_wall' => '4-szekciós beton áttörőfal',
      'deployment_point' => 'Bevetési / belépési pont',
      _ => '3D Pályaelem (${obs.type})',
    };
    return '$containerLabel – $base';
  }

  String _obstacleCategoryKey(String type) {
    return switch (type) {
      'shoring_zone' => 'shoring',
      'lifting_concrete' => 'lifting',
      'wood_beam_30x30x100' => 'breaching',
      'breach_wall' => 'breaching',
      'deployment_point' => 'confined_search',
      _ => 'breaching',
    };
  }

  Future<void> _flushSceneSync() async {
    final repo = widget.repository;
    final exerciseId = widget.exerciseId;
    final raw = _pendingSceneJson;
    if (repo == null || exerciseId == null || raw == null || _syncInFlight) {
      return;
    }
    _pendingSceneJson = null;
    _syncInFlight = true;
    widget.onSavingChanged?.call(true);

    try {
      final scene = ExerciseScene3D.fromJson(raw);

      // 1. Save full structured 3D scene JSONB to Supabase
      await repo.saveExerciseScene3D(exerciseId: exerciseId, scene: scene);

      // 2. Two-way sync with /planning exercise_bubbles (casualty placements + 3D obstacles/windows)
      final details = await repo.fetchExerciseDetails(exerciseId);
      final containerLabels = {
        for (final c in scene.containers) c.id: c.label,
      };

      // 2a. Sync CasualtyPlacement3D -> medical ExerciseBubble specs
      final placementByCasualtyId = {
        for (final p in scene.casualtyPlacements) p.casualtyId: p,
      };
      for (final b in details.bubbles) {
        if (b.discipline != BubbleDiscipline.medical) continue;
        final placement = placementByCasualtyId[b.id];
        final prevPlaced = b.specs['placed_3d'] == true;
        final prevCont = b.specs['container_3d_id']?.toString();
        final nextPlaced = placement?.placed == true;
        final nextCont = nextPlaced ? placement?.containerId : null;
        final nextPos = nextPlaced ? placement?.localPosition : null;

        if (prevPlaced != nextPlaced ||
            prevCont != nextCont ||
            jsonEncode(b.specs['local_pos_3d']) != jsonEncode(nextPos)) {
          final updatedSpecs = <String, dynamic>{
            ...b.specs,
            'placed_3d': nextPlaced,
            'container_3d_id': nextCont,
            'container_3d_label':
                nextCont != null ? containerLabels[nextCont] : null,
            'local_pos_3d': nextPos,
            'pose_3d': placement?.pose ?? 'lying',
          };
          await repo.updateBubbleDetails(
            bubble: b,
            discipline: BubbleDiscipline.medical,
            estimatedHours: b.estimatedHours,
            title: b.title,
            specs: updatedSpecs,
          );
        }
      }

      // 2b. Sync 3D obstacles + concrete windows -> /planning obstacle bubbles (tagged source_3d_id)
      final existing3dBubbles = <String, ExerciseBubble>{};
      for (final b in details.bubbles) {
        final sid = b.specs['source_3d_id']?.toString();
        if (sid != null && sid.isNotEmpty) {
          existing3dBubbles[sid] = b;
        }
      }

      final desired3dItems = <String, ({
        String title,
        String categoryKey,
        String? cpCode,
        String specText,
      })>{};

      for (final obs in scene.obstacles) {
        // Only sync tactical USAR obstacles/entry points to /planning Obstacles board
        if (!const {
          'shoring_zone',
          'lifting_concrete',
          'wood_beam_30x30x100',
          'breach_wall',
          'deployment_point',
        }.contains(obs.type)) {
          continue;
        }
        final cLabel = containerLabels[obs.containerId] ?? '3D Konténer';
        final cp = _findCatalogItem(obs.insaragCheckpointId);
        final cpCode = cp?.code ?? obs.insaragCheckpointId ?? '';
        desired3dItems[obs.id] = (
          title: _obstacleTitleHu(obs, cLabel),
          categoryKey: _obstacleCategoryKey(obs.type),
          cpCode: cpCode,
          specText: cp != null
              ? '${cp.code ?? ''} ${cp.titleHu}'.trim()
              : (obs.type == 'deployment_point'
                  ? 'Manuális INSARAG CP kijelölésre vár'
                  : '3D konténer pályaelem'),
        );
      }

      for (final cont in scene.containers) {
        for (final win in cont.windows) {
          if (win.fillType == 'concrete_panel' ||
              (win.insaragCheckpointId != null &&
                  win.insaragCheckpointId!.isNotEmpty)) {
            final cp = _findCatalogItem(win.insaragCheckpointId);
            final cpCode = cp?.code ?? win.insaragCheckpointId ?? '';
            final isConcrete = win.fillType == 'concrete_panel';
            desired3dItems['win_${win.id}'] = (
              title: isConcrete
                  ? '${cont.label} – Beton ablakpanel áttörés'
                  : '${cont.label} – Átjárható ABLAK nyílás',
              categoryKey: isConcrete ? 'breaching' : 'confined_search',
              cpCode: cpCode,
              specText: cp != null
                  ? '${cp.code ?? ''} ${cp.titleHu}'.trim()
                  : 'Oldalfali nyílás (${win.side})',
            );
          }
        }
      }

      // Upsert desired 3D obstacle bubbles
      for (final entry in desired3dItems.entries) {
        final key = entry.key;
        final item = entry.value;
        final existing = existing3dBubbles.remove(key);
        final specs = <String, dynamic>{
          if (existing != null) ...existing.specs,
          'is_obstacle': true,
          'from_3d_planner': true,
          'source_3d_id': key,
          'obstacle_category': item.categoryKey,
          'insarag_code': item.cpCode ?? '',
          'technical_spec': item.specText,
        };
        if (existing == null) {
          await repo.addBubble(
            exerciseId: exerciseId,
            title: item.title,
            discipline: BubbleDiscipline.custom,
            specs: specs,
          );
        } else if (existing.title != item.title ||
            existing.specs['insarag_code'] != (item.cpCode ?? '') ||
            existing.specs['technical_spec'] != item.specText) {
          await repo.updateBubbleDetails(
            bubble: existing,
            estimatedHours: existing.estimatedHours,
            title: item.title,
            specs: specs,
          );
        }
      }

      // Delete bubbles whose 3D obstacle was removed in the 3D view
      for (final orphan in existing3dBubbles.values) {
        await repo.deleteBubble(
          exerciseId: exerciseId,
          bubbleId: orphan.id,
        );
      }

      _postToIframe({
        'type': 'PLANNER_3D_SYNC_SAVED',
        'savedAt': DateTime.now().toIso8601String(),
      });
    } catch (err) {
      _postToIframe({
        'type': 'PLANNER_3D_SYNC_ERROR',
        'error': err.toString(),
      });
    } finally {
      _syncInFlight = false;
      if (mounted) {
        widget.onSavingChanged?.call(false);
      }
      if (_pendingSceneJson != null) {
        _flushSceneSync();
      }
    }
  }

  @override
  void dispose() {
    _debounceSaveTimer?.cancel();
    if (_messageListener != null) {
      try {
        _window.removeEventListener('message', _messageListener!);
      } catch (_) {}
      _messageListener = null;
    }
    final iframe = _iframe;
    _iframe = null;
    if (iframe != null) {
      try {
        final payload = <String, Object?>{'type': 'DISPOSE_3D_PLANNER'}.jsify();
        iframe.contentWindow?.postMessage(payload, '*');
      } catch (_) {}
      try {
        iframe.src = 'about:blank';
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox.expand(
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
