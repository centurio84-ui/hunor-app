class QuizEvent {
  const QuizEvent({
    required this.id,
    required this.slug,
    required this.title,
    required this.isActive,
    required this.questionCount,
    required this.minScore,
    required this.createdAt,
    this.staffPin = '1234',
    this.startedCount = 0,
    this.completedCount = 0,
    this.qualifiedCount = 0,
    this.redeemedCount = 0,
  });

  final String id;
  final String slug;
  final String title;
  final bool isActive;
  final int questionCount;
  final int minScore;
  final String staffPin;
  final DateTime createdAt;

  // Live metrics (populated in Admin Event Manager)
  final int startedCount;
  final int completedCount;
  final int qualifiedCount;
  final int redeemedCount;

  int get dropOffCount =>
      (startedCount - completedCount).clamp(0, startedCount);

  double get dropOffRatePercent =>
      startedCount <= 0 ? 0.0 : (dropOffCount / startedCount) * 100.0;

  String get qrDeepLink => 'https://hun01usar.hu/#/quiz?event=$slug';

  factory QuizEvent.fromJson(Map<String, dynamic> json) {
    return QuizEvent(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      isActive: json['is_active'] != false,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 10,
      minScore: (json['min_score'] as num?)?.toInt() ?? 7,
      staffPin: (json['staff_pin'] ?? '1234').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      startedCount: (json['started_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      qualifiedCount: (json['qualified_count'] as num?)?.toInt() ?? 0,
      redeemedCount: (json['redeemed_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuizEventSubmission {
  const QuizEventSubmission({
    required this.id,
    required this.eventId,
    required this.startedAt,
    this.completedAt,
    this.score,
    this.rewardCode,
    this.isRedeemed = false,
  });

  final String id;
  final String eventId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? score;
  final String? rewardCode;
  final bool isRedeemed;

  bool get isCompleted => completedAt != null;

  factory QuizEventSubmission.fromJson(Map<String, dynamic> json) {
    return QuizEventSubmission(
      id: (json['id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()) ??
          DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      score: (json['score'] as num?)?.toInt(),
      rewardCode: json['reward_code'] as String?,
      isRedeemed: json['is_redeemed'] == true,
    );
  }
}

class QuizQuestionItem {
  const QuizQuestionItem({
    required this.id,
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
    required this.category,
  });

  final String id;
  final String question;
  final List<String> choices;
  final int correctIndex;
  final String explanation;
  final String category;

  factory QuizQuestionItem.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['choices'];
    return QuizQuestionItem(
      id: (json['id'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      choices: rawChoices is List
          ? [for (final c in rawChoices) c.toString()]
          : const [],
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
      explanation: (json['explanation'] ?? '').toString(),
      category: (json['category'] ?? 'Vészhelyzeti felkészültség').toString(),
    );
  }
}
