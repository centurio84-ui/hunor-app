class ExconEvaluation {
  final String? id;
  final DateTime? createdAt;
  final String evaluatorName;
  final String checkpointCode;
  final int score; // 0, 1, vagy 2
  final String? comment;

  const ExconEvaluation({
    this.id,
    this.createdAt,
    required this.evaluatorName,
    required this.checkpointCode,
    required this.score,
    this.comment,
  }) : assert(score >= 0 && score <= 2, 'A pontszámnak 0, 1 vagy 2-nek kell lennie');

  factory ExconEvaluation.fromJson(Map<String, dynamic> json) {
    return ExconEvaluation(
      id: json['id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      evaluatorName: json['evaluator_name'] as String? ?? '',
      checkpointCode: json['checkpoint_code'] as String? ?? '',
      score: (json['score'] as num).toInt(),
      comment: json['comment'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'evaluator_name': evaluatorName,
      'checkpoint_code': checkpointCode,
      'score': score,
      if (comment != null && comment!.trim().isNotEmpty)
        'comment': comment!.trim(),
    };
  }
}
