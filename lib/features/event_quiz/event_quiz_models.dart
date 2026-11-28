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

String formatQuizDurationMs(int? durationMs) {
  if (durationMs == null || durationMs <= 0) return '—';
  final totalSeconds = durationMs / 1000.0;
  if (totalSeconds < 60) {
    return '${totalSeconds.toStringAsFixed(1)} mp';
  }
  final mins = durationMs ~/ 60000;
  final remSec = ((durationMs % 60000) / 1000.0);
  return '$mins p ${remSec.toStringAsFixed(1)} mp';
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

class QuizLeaderEntry {
  const QuizLeaderEntry({
    required this.submissionId,
    required this.participantName,
    required this.score,
    required this.durationMs,
    required this.completedAt,
  });

  final String submissionId;
  final String participantName;
  final int score;
  final int durationMs;
  final DateTime completedAt;

  String get formattedDuration => formatQuizDurationMs(durationMs);
}

class QuizHourlyNotification {
  const QuizHourlyNotification({
    required this.id,
    required this.eventId,
    required this.hourBucket,
    required this.summaryText,
    required this.createdAt,
    this.hourlyWinnerName,
    this.hourlyWinnerScore,
    this.hourlyWinnerDurationMs,
    this.hourlyCompletionsCount = 0,
    this.overallWinnerName,
    this.overallWinnerScore,
    this.overallWinnerDurationMs,
    this.overallCompletionsCount = 0,
  });

  final String id;
  final String eventId;
  final DateTime hourBucket;
  final String? hourlyWinnerName;
  final int? hourlyWinnerScore;
  final int? hourlyWinnerDurationMs;
  final int hourlyCompletionsCount;
  final String? overallWinnerName;
  final int? overallWinnerScore;
  final int? overallWinnerDurationMs;
  final int overallCompletionsCount;
  final String summaryText;
  final DateTime createdAt;

  factory QuizHourlyNotification.fromJson(Map<String, dynamic> json) {
    return QuizHourlyNotification(
      id: (json['id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      hourBucket:
          DateTime.tryParse((json['hour_bucket'] ?? '').toString()) ??
              DateTime.now(),
      hourlyWinnerName: json['hourly_winner_name']?.toString(),
      hourlyWinnerScore: (json['hourly_winner_score'] as num?)?.toInt(),
      hourlyWinnerDurationMs:
          (json['hourly_winner_duration_ms'] as num?)?.toInt(),
      hourlyCompletionsCount:
          (json['hourly_completions_count'] as num?)?.toInt() ?? 0,
      overallWinnerName: json['overall_winner_name']?.toString(),
      overallWinnerScore: (json['overall_winner_score'] as num?)?.toInt(),
      overallWinnerDurationMs:
          (json['overall_winner_duration_ms'] as num?)?.toInt(),
      overallCompletionsCount:
          (json['overall_completions_count'] as num?)?.toInt() ?? 0,
      summaryText: (json['summary_text'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
              DateTime.now(),
    );
  }
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
    this.rewardEnabled = false,
    this.rewardName = '',
    this.requireParticipantName = true,
    this.hourlyLeaderNotify = true,
    this.staffPin = '1234',
    this.startedCount = 0,
    this.completedCount = 0,
    this.winnersCount = 0,
    this.redeemedCount = 0,
    this.topLeaders = const [],
    this.lastHourLeader,
    this.lastHourCompletions = 0,
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
  final bool requireParticipantName;
  final bool hourlyLeaderNotify;
  final String staffPin;
  final DateTime createdAt;

  /// True ONLY when the organizer explicitly enabled a reward AND entered its name.
  bool get hasConfiguredReward =>
      rewardEnabled && rewardName.trim().isNotEmpty;

  // Live statistics from quiz_event_submissions
  final int startedCount;
  final int completedCount;
  final int winnersCount;
  final int redeemedCount;
  final List<QuizLeaderEntry> topLeaders;
  final QuizLeaderEntry? lastHourLeader;
  final int lastHourCompletions;

  QuizLeaderEntry? get overallLeader =>
      topLeaders.isNotEmpty ? topLeaders.first : null;

  int get abandonedCount =>
      (startedCount - completedCount).clamp(0, startedCount);

  double get dropOffRatePercent =>
      startedCount <= 0 ? 0.0 : (abandonedCount / startedCount) * 100.0;

  /// Clean path URL (no `#` fragment) so Facebook/Messenger/Viber/WhatsApp render a clickable OG preview card AND QR scanners open directly!
  String get qrDeepLink => 'https://hun01usar.hu/quiz?event=$slug';

  String get socialPostCaption =>
      '🔥 ${title.toUpperCase()} – VÉSZHELYZETI KVÍZ!\n'
      'Tedd próbára a tudásod $questionCount gyors kérdéssel – azonnali magyarázattal!\n'
      '👉 Kattints ide a kvíz indításához: $qrDeepLink';

  QuizEvent copyWithMetrics({
    required int startedCount,
    required int completedCount,
    required int winnersCount,
    required int redeemedCount,
    List<QuizLeaderEntry> topLeaders = const [],
    QuizLeaderEntry? lastHourLeader,
    int lastHourCompletions = 0,
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
      requireParticipantName: requireParticipantName,
      hourlyLeaderNotify: hourlyLeaderNotify,
      staffPin: staffPin,
      createdAt: createdAt,
      startedCount: startedCount,
      completedCount: completedCount,
      winnersCount: winnersCount,
      redeemedCount: redeemedCount,
      topLeaders: topLeaders,
      lastHourLeader: lastHourLeader,
      lastHourCompletions: lastHourCompletions,
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
    final cleanedRewardName =
        rawRewardName == 'Ajándék nyeremény' ? '' : rawRewardName;
    final parsedRewardEnabled =
        json['reward_enabled'] == true && cleanedRewardName.isNotEmpty;

    return QuizEvent(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      selectedCategories:
          parsedCats.isEmpty ? const ['altalanos'] : parsedCats,
      isActive: json['is_active'] != false,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 10,
      minScore: (json['min_score'] as num?)?.toInt() ?? 8,
      rewardEnabled: parsedRewardEnabled,
      rewardName: parsedRewardEnabled ? cleanedRewardName : '',
      requireParticipantName: json['require_participant_name'] != false,
      hourlyLeaderNotify: json['hourly_leader_notify'] != false,
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
    this.participantName,
    this.completedAt,
    this.durationMs,
    this.score,
    this.rewardCode,
    this.isRedeemed = false,
  });

  final String id;
  final String eventId;
  final String deviceHash;
  final String? participantName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationMs;
  final int? score;
  final String? rewardCode;
  final bool isRedeemed;

  bool get isCompleted => completedAt != null;

  int? get effectiveDurationMs {
    if (durationMs != null && durationMs! > 0) return durationMs;
    if (completedAt != null) {
      final diff = completedAt!.difference(startedAt).inMilliseconds;
      if (diff > 0) return diff;
    }
    return null;
  }

  factory QuizEventSubmission.fromJson(Map<String, dynamic> json) {
    final rawName = json['participant_name']?.toString().trim();
    return QuizEventSubmission(
      id: (json['id'] ?? '').toString(),
      eventId: (json['event_id'] ?? '').toString(),
      deviceHash: (json['device_hash'] ?? '').toString(),
      participantName: (rawName != null && rawName.isNotEmpty) ? rawName : null,
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()) ??
          DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
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
