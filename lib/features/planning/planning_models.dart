class InsaragCheckpoint {
  const InsaragCheckpoint({
    required this.id,
    required this.titleHu,
    required this.sortOrder,
    this.code,
    this.titleEn,
    this.category,
    this.defaultDurationHours,
  });

  final String id;
  final String titleHu;
  final int sortOrder;
  final String? code;
  final String? titleEn;
  final String? category;
  final double? defaultDurationHours;

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
  });

  final String id;
  final String exerciseId;
  final String name;
  final int number;

  factory ExerciseSector.fromJson(Map<String, dynamic> json) {
    return ExerciseSector(
      id: json['id'] as String,
      exerciseId: json['exercise_id'] as String,
      name: json['name'] as String,
      number: json['number'] as int,
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
