import 'package:flutter/material.dart';

class InsaragSection {
  const InsaragSection({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;

  static const List<InsaragSection> all = [
    InsaragSection(key: '4', label: '4. USAR csapat felépítése', color: Color(0xFF6366F1)),
    InsaragSection(key: '5', label: '5. Logisztika', color: Color(0xFFD97706)),
    InsaragSection(key: '6', label: '6. Képzés', color: Color(0xFF0D9488)),
    InsaragSection(key: '7', label: '7. Kommunikáció és technológia', color: Color(0xFF0284C7)),
    InsaragSection(key: '8', label: '8. Dokumentáció', color: Color(0xFF64748B)),
    InsaragSection(key: '9', label: '9. Riasztás és mobilizáció', color: Color(0xFFEA580C)),
    InsaragSection(key: '10', label: '10. Műveleti bázis (BoO)', color: Color(0xFF059669)),
    InsaragSection(key: '11', label: '11. Tervezés', color: Color(0xFF7C3AED)),
    InsaragSection(key: '12', label: '12. USAR koordináció', color: Color(0xFF2563EB)),
    InsaragSection(key: '13', label: '13. Felmérés, kutatás és mentés', color: Color(0xFF0891B2)),
    InsaragSection(key: '14', label: '14. Műveletek', color: Color(0xFFE11D48)),
    InsaragSection(key: '15', label: '15. Demobilizáció és kivonulás', color: Color(0xFF65A30D)),
    InsaragSection(key: '16', label: '16. Gyakorlatirányítás (EXCON)', color: Color(0xFFC026D3)),
  ];

  static InsaragSection? byKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final s in all) {
      if (s.key == key) return s;
    }
    return null;
  }
}

class InsaragCheckpoint {
  const InsaragCheckpoint({
    required this.id,
    required this.titleHu,
    required this.sortOrder,
    this.code,
    this.titleEn,
    this.category,
    this.defaultDurationHours,
    this.clarificationHu,
  });

  final String id;
  final String titleHu;
  final int sortOrder;
  final String? code;
  final String? titleEn;
  final String? category;
  final double? defaultDurationHours;
  final String? clarificationHu;

  InsaragSection? get section => InsaragSection.byKey(category);

  factory InsaragCheckpoint.fromJson(Map<String, dynamic> json) {
    return InsaragCheckpoint(
      id: json['id'] as String,
      titleHu: (json['title_hu'] ?? json['title']) as String,
      sortOrder: json['sort_order'] as int,
      code: json['code'] as String?,
      titleEn: json['title_en'] as String?,
      category: json['category'] as String?,
      defaultDurationHours:
          (json['default_duration_hours'] as num?)?.toDouble(),
      clarificationHu: json['clarification_hu'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'titleHu': titleHu,
        'titleEn': titleEn,
        'category': category,
        'sortOrder': sortOrder,
      };
}

class ContainerWindow3D {
  const ContainerWindow3D({
    required this.id,
    required this.side,
    required this.offsetAlongWall,
    required this.fillType,
    this.insaragCheckpointId,
  });

  final String id;
  final String side; // 'left' | 'right' | 'front' | 'back'
  final double offsetAlongWall;
  final String fillType; // 'open_window' | 'concrete_panel'
  final String? insaragCheckpointId;

  factory ContainerWindow3D.fromJson(Map<String, dynamic> json) {
    return ContainerWindow3D(
      id: (json['id'] ?? '').toString(),
      side: (json['side'] ?? 'right').toString(),
      offsetAlongWall: (json['offsetAlongWall'] as num?)?.toDouble() ?? 0.0,
      fillType: (json['fillType'] ?? 'open_window').toString(),
      insaragCheckpointId: json['insaragCheckpointId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'side': side,
        'offsetAlongWall': offsetAlongWall,
        'fillType': fillType,
        'insaragCheckpointId': insaragCheckpointId,
      };
}

class Container3D {
  const Container3D({
    required this.id,
    required this.label,
    required this.position,
    required this.rotationY,
    this.color = '#8b261d',
    this.windows = const [],
  });

  final String id;
  final String label;
  final List<double> position;
  final double rotationY;
  final String color;
  final List<ContainerWindow3D> windows;

  factory Container3D.fromJson(Map<String, dynamic> json) {
    final rawPos = json['position'];
    final pos = rawPos is List && rawPos.length >= 3
        ? [
            (rawPos[0] as num?)?.toDouble() ?? 0.0,
            (rawPos[1] as num?)?.toDouble() ?? 0.0,
            (rawPos[2] as num?)?.toDouble() ?? 0.0,
          ]
        : <double>[0.0, 0.0, 0.0];
    final rawWin = json['windows'];
    return Container3D(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? 'WS-1 Konténer').toString(),
      position: pos,
      rotationY: (json['rotationY'] as num?)?.toDouble() ?? 0.0,
      color: (json['color'] ?? '#8b261d').toString(),
      windows: rawWin is List
          ? rawWin
              .whereType<Map>()
              .map((w) =>
                  ContainerWindow3D.fromJson(Map<String, dynamic>.from(w)))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'position': position,
        'rotationY': rotationY,
        'color': color,
        'windows': [for (final w in windows) w.toJson()],
      };
}

class Obstacle3D {
  const Obstacle3D({
    required this.id,
    required this.containerId,
    required this.type,
    required this.localPosition,
    required this.rotationY,
    this.dimensions,
    this.insaragCheckpointId,
    this.linkedTimelineEventId,
    this.linkedBubbleId,
    this.slots,
    this.extra,
  });

  final String id;
  final String containerId;
  final String type;
  final List<double> localPosition;
  final double rotationY;
  final List<double>? dimensions;
  final String? insaragCheckpointId;
  final String? linkedTimelineEventId;
  final String? linkedBubbleId;
  final List<String>? slots;
  final Map<String, dynamic>? extra;

  factory Obstacle3D.fromJson(Map<String, dynamic> json) {
    final rawPos = json['localPosition'];
    final pos = rawPos is List && rawPos.length >= 3
        ? [
            (rawPos[0] as num?)?.toDouble() ?? 0.0,
            (rawPos[1] as num?)?.toDouble() ?? 0.0,
            (rawPos[2] as num?)?.toDouble() ?? 0.0,
          ]
        : <double>[0.0, 0.0, 0.0];
    final rawDim = json['dimensions'];
    final dims = rawDim is List && rawDim.length >= 3
        ? [
            (rawDim[0] as num?)?.toDouble() ?? 1.0,
            (rawDim[1] as num?)?.toDouble() ?? 1.0,
            (rawDim[2] as num?)?.toDouble() ?? 1.0,
          ]
        : null;
    final rawSlots = json['slots'];
    return Obstacle3D(
      id: (json['id'] ?? '').toString(),
      containerId: (json['containerId'] ?? '').toString(),
      type: (json['type'] ?? 'lifting_concrete').toString(),
      localPosition: pos,
      rotationY: (json['rotationY'] as num?)?.toDouble() ?? 0.0,
      dimensions: dims,
      insaragCheckpointId: json['insaragCheckpointId'] as String?,
      linkedTimelineEventId: json['linkedTimelineEventId'] as String?,
      linkedBubbleId: json['linkedBubbleId'] as String?,
      slots: rawSlots is List
          ? [for (final s in rawSlots) s.toString()]
          : null,
      extra: json['extra'] is Map
          ? Map<String, dynamic>.from(json['extra'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'containerId': containerId,
        'type': type,
        'localPosition': localPosition,
        'rotationY': rotationY,
        if (dimensions != null) 'dimensions': dimensions,
        'insaragCheckpointId': insaragCheckpointId,
        if (linkedTimelineEventId != null)
          'linkedTimelineEventId': linkedTimelineEventId,
        if (linkedBubbleId != null) 'linkedBubbleId': linkedBubbleId,
        if (slots != null) 'slots': slots,
        if (extra != null) 'extra': extra,
      };
}

class CasualtyPlacement3D {
  const CasualtyPlacement3D({
    required this.casualtyId,
    required this.placed,
    this.containerId,
    this.localPosition,
    this.rotationY = 0.0,
    this.pose = 'lying',
  });

  final String casualtyId;
  final bool placed;
  final String? containerId;
  final List<double>? localPosition;
  final double rotationY;
  final String pose;

  factory CasualtyPlacement3D.fromJson(Map<String, dynamic> json) {
    final rawPos = json['localPosition'];
    final pos = rawPos is List && rawPos.length >= 3
        ? [
            (rawPos[0] as num?)?.toDouble() ?? 0.0,
            (rawPos[1] as num?)?.toDouble() ?? 0.0,
            (rawPos[2] as num?)?.toDouble() ?? 0.0,
          ]
        : null;
    return CasualtyPlacement3D(
      casualtyId: (json['casualtyId'] ?? '').toString(),
      placed: json['placed'] == true,
      containerId: json['containerId'] as String?,
      localPosition: pos,
      rotationY: (json['rotationY'] as num?)?.toDouble() ?? 0.0,
      pose: (json['pose'] ?? 'lying').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'casualtyId': casualtyId,
        'placed': placed,
        if (containerId != null) 'containerId': containerId,
        if (localPosition != null) 'localPosition': localPosition,
        'rotationY': rotationY,
        'pose': pose,
      };
}

class ExerciseScene3D {
  const ExerciseScene3D({
    this.containers = const [],
    this.obstacles = const [],
    this.casualtyPlacements = const [],
    this.labelsVisible = true,
  });

  final List<Container3D> containers;
  final List<Obstacle3D> obstacles;
  final List<CasualtyPlacement3D> casualtyPlacements;
  final bool labelsVisible;

  bool get isEmpty =>
      containers.isEmpty && obstacles.isEmpty && casualtyPlacements.isEmpty;

  factory ExerciseScene3D.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const ExerciseScene3D();
    final rawC = json['containers'];
    final rawO = json['obstacles'];
    final rawP = json['casualtyPlacements'];
    return ExerciseScene3D(
      containers: rawC is List
          ? rawC
              .whereType<Map>()
              .map((c) => Container3D.fromJson(Map<String, dynamic>.from(c)))
              .toList()
          : const [],
      obstacles: rawO is List
          ? rawO
              .whereType<Map>()
              .map((o) => Obstacle3D.fromJson(Map<String, dynamic>.from(o)))
              .toList()
          : const [],
      casualtyPlacements: rawP is List
          ? rawP
              .whereType<Map>()
              .map((p) =>
                  CasualtyPlacement3D.fromJson(Map<String, dynamic>.from(p)))
              .toList()
          : const [],
      labelsVisible: json['labelsVisible'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 3,
        'labelsVisible': labelsVisible,
        'containers': [for (final c in containers) c.toJson()],
        'obstacles': [for (final o in obstacles) o.toJson()],
        'casualtyPlacements': [for (final p in casualtyPlacements) p.toJson()],
      };
}

class Exercise {
  const Exercise({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.createdAt,
    this.scene3d = const ExerciseScene3D(),
  });

  final String id;
  final String organizationId;
  final String title;
  final DateTime createdAt;
  final ExerciseScene3D scene3d;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final rawScene = json['scene_3d'];
    return Exercise(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      scene3d: rawScene is Map
          ? ExerciseScene3D.fromJson(Map<String, dynamic>.from(rawScene))
          : const ExerciseScene3D(),
    );
  }
}

class ExerciseSector {
  const ExerciseSector({
    required this.id,
    required this.exerciseId,
    required this.name,
    required this.number,
    this.icmsName = '',
    this.description = '',
  });

  final String id;
  final String exerciseId;
  final String name;
  final int number;
  final String icmsName;
  final String description;

  factory ExerciseSector.fromJson(Map<String, dynamic> json) {
    return ExerciseSector(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      name: json['name'] as String,
      number: json['number'] as int,
      icmsName: (json['icms_name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
    );
  }
}

class ExerciseBubble {
  ExerciseBubble({
    required this.id,
    required this.exerciseId,
    required this.checkpointId,
    required this.bubbleType,
    required this.sectorId,
    required this.estimatedHours,
    required this.title,
    required Map<String, dynamic> specs,
  }) : specs = Map.unmodifiable(specs);

  final String id;
  final String exerciseId;
  final String? checkpointId;
  final String bubbleType;
  BubbleDiscipline get discipline => BubbleDiscipline.fromValue(bubbleType);
  final String? sectorId;
  final double? estimatedHours;
  final String title;
  final Map<String, dynamic> specs;

  factory ExerciseBubble.fromJson(Map<String, dynamic> json) {
    return ExerciseBubble(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      checkpointId: json['checkpoint_id'] as String?,
      bubbleType: json['bubble_type'] as String? ??
          (json['checkpoint_id'] == null ? 'custom' : 'checkpoint'),
      sectorId: json['sector_id'] as String?,
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble(),
      title: json['title'] as String,
      specs: json['specs'] as Map<String, dynamic>,
    );
  }
}

typedef ExerciseDetails = ({
  List<ExerciseSector> sectors,
  List<ExerciseBubble> bubbles,
});

enum BubbleDiscipline {
  checkpoint('checkpoint', 'INSARAG / műszaki'),
  custom('custom', 'Egyedi'),
  medical('medical', 'Egészségügy / EÜ'),
  ucc('ucc', 'UCC / törzs'),
  pressVip('press_vip', 'Sajtó / VIP / LEMA');

  const BubbleDiscipline(this.value, this.label);
  final String value;
  final String label;

  static BubbleDiscipline fromValue(String value) =>
      values.firstWhere((type) => type.value == value, orElse: () => custom);
}

enum TimelineStatus {
  planned('planned', 'Tervezett'),
  inProgress('in_progress', 'Folyamatban'),
  delayed('delayed', 'Késik'),
  completed('completed', 'Befejezett');

  const TimelineStatus(this.value, this.label);
  final String value;
  final String label;
}

class TimelineTiming {
  const TimelineTiming(this.start, this.duration);

  final double start;
  final double duration;

  double get end => start + duration;

  bool get isValid =>
      start.isFinite &&
      start >= 0 &&
      duration.isFinite &&
      duration > 0 &&
      end.isFinite;
}

class ExerciseTimelineBlock {
  const ExerciseTimelineBlock({
    required this.id,
    required this.exerciseId,
    required this.bubbleId,
    required this.sectorId,
    required this.planned,
    required this.actual,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String exerciseId;
  final String bubbleId;
  final String? sectorId;
  final TimelineTiming planned;
  final TimelineTiming? actual;
  final TimelineStatus status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  double? get endVariance => actual == null ? null : actual!.end - planned.end;

  factory ExerciseTimelineBlock.fromJson(Map<String, dynamic> json) {
    return ExerciseTimelineBlock(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      bubbleId: json['bubble_id'] as String,
      sectorId: json['sector_id'] as String?,
      planned: TimelineTiming(
        (json['planned_start_hour'] as num).toDouble(),
        (json['planned_duration_hours'] as num).toDouble(),
      ),
      actual: json['is_copied_to_actual'] == true
          ? TimelineTiming(
              (json['actual_start_hour'] as num).toDouble(),
              (json['actual_duration_hours'] as num).toDouble(),
            )
          : null,
      status: TimelineStatus.values.firstWhere(
        (status) => status.value == json['status'],
      ),
      notes: json['notes'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
