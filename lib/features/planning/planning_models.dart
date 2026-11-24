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
}

class Exercise {
  const Exercise({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.createdAt,
  });

  final String id;
  final String organizationId;
  final String title;
  final DateTime createdAt;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
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
