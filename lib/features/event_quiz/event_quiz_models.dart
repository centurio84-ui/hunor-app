import 'dart:convert';

const Map<String, String> kQuizCategoryLabels = {
  'altalanos': 'Általános lakossági felkészültség',
  'advent': 'Advent és ünnepi tűzvédelem',
  'teli_idojaras': 'Téli rendkívüli időjárás',
  'arviz_belviz': 'Árvíz, villámárvíz és belvíz',
  'szabadteri_tuz': 'Tavaszi szabadtéri tűzvédelem',
};

const List<String> kDefaultCategoryOrder = [
  'altalanos',
  'advent',
  'teli_idojaras',
  'arviz_belviz',
  'szabadteri_tuz',
];

String quizCategoryLabel(String rawCategory) {
  final key = rawCategory.trim();
  if (key.isEmpty) return kQuizCategoryLabels['altalanos']!;
  final mapped = kQuizCategoryLabels[key];
  if (mapped != null) return mapped;
  final cleaned = key.replaceAll('_', ' ');
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

class QuizCategoryStat {
  const QuizCategoryStat({
    required this.category,
    required this.count,
  });

  final String category;
  final int count;

  String get label => quizCategoryLabel(category);
}

class QuizEvent {
  const QuizEvent({
    required this.id,
    required this.slug,
    required this.title,
    required this.selectedCategories,
    required this.isActive,
    required this.questionCount,
    required this.minScore,
    required this.createdAt,
    this.rewardEnabled = true,
    this.rewardName = 'Ajándék nyeremény',
    this.staffPin = '1234',
    this.startedCount = 0,
    this.completedCount = 0,
    this.winnersCount = 0,
    this.redeemedCount = 0,
  });

  final String id;
  final String slug;
  final String title;
  final List<String> selectedCategories;
  final bool isActive;
  final int questionCount;
  final int minScore;
  final bool rewardEnabled;
  final String rewardName;
  final String staffPin;
  final DateTime createdAt;

  // Live statistics from quiz_event_submissions
  final int startedCount;
  final int completedCount;
  final int winnersCount;
  final int redeemedCount;

  int get abandonedCount =>
      (startedCount - completedCount).clamp(0, startedCount);

  double get dropOffRatePercent =>
      startedCount <= 0 ? 0.0 : (abandonedCount / startedCount) * 100.0;

  String get qrDeepLink => 'https://hun01usar.hu/#/quiz?event=$slug';

  QuizEvent copyWithMetrics({
    required int startedCount,
    required int completedCount,
    required int winnersCount,
    required int redeemedCount,
  }) {
    return QuizEvent(
      id: id,
      slug: slug,
      title: title,
      selectedCategories: selectedCategories,
      isActive: isActive,
      questionCount: questionCount,
      minScore: minScore,
      rewardEnabled: rewardEnabled,
      rewardName: rewardName,
      staffPin: staffPin,
      createdAt: createdAt,
      startedCount: startedCount,
      completedCount: completedCount,
      winnersCount: winnersCount,
      redeemedCount: redeemedCount,
    );
  }

  factory QuizEvent.fromJson(Map<String, dynamic> json) {
    final rawCats = json['selected_categories'];
    final parsedCats = rawCats is List
        ? rawCats
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    final rawRewardName = (json['reward_name'] ?? '').toString().trim();

    return QuizEvent(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      selectedCategories:
          parsedCats.isEmpty ? const ['altalanos'] : parsedCats,
      isActive: json['is_active'] != false,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 10,
      minScore: (json['min_score'] as num?)?.toInt() ?? 8,
      rewardEnabled: json['reward_enabled'] != false,
      rewardName:
          rawRewardName.isEmpty ? 'Ajándék nyeremény' : rawRewardName,
      staffPin: (json['staff_pin'] ?? '1234').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      startedCount: (json['started_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      winnersCount: (json['winners_count'] as num?)?.toInt() ??
          (json['qualified_count'] as num?)?.toInt() ??
          0,
      redeemedCount: (json['redeemed_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuizEventSubmission {
  const QuizEventSubmission({
    required this.id,
    required this.eventId,
    required this.startedAt,
    this.deviceHash = '',
    this.completedAt,
    this.score,
    this.rewardCode,
    this.isRedeemed = false,
  });

  final String id;
  final String eventId;
  final String deviceHash;
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
      deviceHash: (json['device_hash'] ?? '').toString(),
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
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.category,
  });

  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String category;

  String get categoryLabel => quizCategoryLabel(category);

  factory QuizQuestionItem.fromJson(Map<String, dynamic> json) {
    final rawOpts = json['options'] ?? json['choices'];
    List<String> parsedOpts = const [];
    if (rawOpts is List) {
      parsedOpts = [for (final c in rawOpts) c.toString()];
    } else if (rawOpts is String && rawOpts.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawOpts);
        if (decoded is List) {
          parsedOpts = [for (final c in decoded) c.toString()];
        }
      } catch (_) {}
    }

    final idx = (json['correct_index'] as num?)?.toInt() ??
        (json['correctIndex'] as num?)?.toInt() ??
        0;

    final rawCategory = (json['category'] ?? 'altalanos').toString().trim();

    return QuizQuestionItem(
      id: (json['id'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      options: parsedOpts,
      correctIndex: idx,
      explanation: (json['explanation'] ?? '').toString(),
      category: rawCategory.isEmpty ? 'altalanos' : rawCategory,
    );
  }
}
