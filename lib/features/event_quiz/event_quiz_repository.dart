import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_quiz_models.dart';

class EventQuizRepository {
  EventQuizRepository(this._client);

  final SupabaseClient _client;
  final Random _rng = Random();

  // ===========================================================================
  // PUBLIC / GUEST QUIZ FLOW
  // ===========================================================================

  Future<({QuizEvent? event, QuizEventSubmission? submission})>
      fetchPublicEventState({
    required String slug,
    required String deviceHash,
  }) async {
    final cleanSlug = slug.trim().toLowerCase();
    if (cleanSlug.isEmpty) return (event: null, submission: null);

    try {
      final eventRow = await _client
          .from('quiz_events')
          .select()
          .eq('slug', cleanSlug)
          .maybeSingle();

      if (eventRow == null) {
        return (event: null, submission: null);
      }

      final event = QuizEvent.fromJson(Map<String, dynamic>.from(eventRow));
      final subRow = await _client
          .from('quiz_event_submissions')
          .select()
          .eq('event_id', event.id)
          .eq('device_hash', deviceHash)
          .maybeSingle();

      final sub = subRow != null
          ? QuizEventSubmission.fromJson(Map<String, dynamic>.from(subRow))
          : null;

      return (event: event, submission: sub);
    } catch (_) {
      // Fallback to RPC if table grants were not yet refreshed
      final res = await _client.rpc(
        'get_public_quiz_event_state',
        params: {
          'p_slug': cleanSlug,
          'p_device_hash': deviceHash,
        },
      );
      if (res is! Map || res['found'] != true) {
        return (event: null, submission: null);
      }
      final rawEvent = res['event'];
      final rawSub = res['submission'];
      return (
        event: rawEvent is Map
            ? QuizEvent.fromJson(Map<String, dynamic>.from(rawEvent))
            : null,
        submission: rawSub is Map
            ? QuizEventSubmission.fromJson(Map<String, dynamic>.from(rawSub))
            : null,
      );
    }
  }

  /// Upserts a row with `started_at = now()` on `(event_id, device_hash)` to track opens vs. completions.
  /// If a row already exists (e.g. already started or already completed), preserves it.
  Future<QuizEventSubmission> startQuiz({
    required String eventId,
    required String deviceHash,
  }) async {
    try {
      final existing = await _client
          .from('quiz_event_submissions')
          .select()
          .eq('event_id', eventId)
          .eq('device_hash', deviceHash)
          .maybeSingle();

      if (existing != null) {
        return QuizEventSubmission.fromJson(
          Map<String, dynamic>.from(existing),
        );
      }

      final inserted = await _client
          .from('quiz_event_submissions')
          .upsert(
            {
              'event_id': eventId,
              'device_hash': deviceHash,
              'started_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'event_id,device_hash',
          )
          .select()
          .single();

      return QuizEventSubmission.fromJson(Map<String, dynamic>.from(inserted));
    } catch (_) {
      final res = await _client.rpc(
        'start_quiz_event_submission',
        params: {
          'p_event_id': eventId,
          'p_device_hash': deviceHash,
        },
      );
      return QuizEventSubmission.fromJson(
        Map<String, dynamic>.from(res as Map),
      );
    }
  }

  /// Marks submission completed (`completed_at = now()`, `score`), and if `score >= event.minScore`
  /// generates a unique coupon code (e.g. `HUNOR-742`) saved in `reward_code`.
  Future<QuizEventSubmission> completeQuiz({
    required QuizEvent event,
    required String deviceHash,
    required int score,
  }) async {
    try {
      final existingRow = await _client
          .from('quiz_event_submissions')
          .select()
          .eq('event_id', event.id)
          .eq('device_hash', deviceHash)
          .maybeSingle();

      if (existingRow != null) {
        final existingSub = QuizEventSubmission.fromJson(
          Map<String, dynamic>.from(existingRow),
        );
        // One-attempt lock: never overwrite an already completed result!
        if (existingSub.isCompleted) {
          return existingSub;
        }
      }

      final bool won = event.hasConfiguredReward && score >= event.minScore;
      String? rewardCode;
      final completedIso = DateTime.now().toUtc().toIso8601String();

      for (var attempt = 0; attempt < 15; attempt++) {
        rewardCode = won ? _generateRewardCode(attempt) : null;
        try {
          if (existingRow != null) {
            final updated = await _client
                .from('quiz_event_submissions')
                .update({
                  'completed_at': completedIso,
                  'score': score,
                  'reward_code': rewardCode,
                })
                .eq('id', existingRow['id'].toString())
                .select()
                .single();
            return QuizEventSubmission.fromJson(
              Map<String, dynamic>.from(updated),
            );
          } else {
            final inserted = await _client
                .from('quiz_event_submissions')
                .insert({
                  'event_id': event.id,
                  'device_hash': deviceHash,
                  'started_at': completedIso,
                  'completed_at': completedIso,
                  'score': score,
                  'reward_code': rewardCode,
                })
                .select()
                .single();
            return QuizEventSubmission.fromJson(
              Map<String, dynamic>.from(inserted),
            );
          }
        } catch (err) {
          final msg = err.toString().toLowerCase();
          if (won && msg.contains('reward_code')) {
            // Rare collision on reward_code — retry with a fresh code
            continue;
          }
          rethrow;
        }
      }
      throw StateError('Nem sikerült egyedi kuponkódot generálni.');
    } catch (_) {
      final res = await _client.rpc(
        'complete_quiz_event_submission',
        params: {
          'p_event_id': event.id,
          'p_device_hash': deviceHash,
          'p_score': score,
        },
      );
      return QuizEventSubmission.fromJson(
        Map<String, dynamic>.from(res as Map),
      );
    }
  }

  /// Generates a clean, memorable reward coupon code (e.g. `KUPON-742`).
  String _generateRewardCode(int attempt) {
    if (attempt < 6) {
      final numPart = 100 + _rng.nextInt(900); // 100..999 -> e.g. KUPON-742
      return 'KUPON-$numPart';
    }
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final suffix = List.generate(
      4,
      (_) => chars[_rng.nextInt(chars.length)],
    ).join();
    return 'KUPON-$suffix';
  }

  /// Validates the 4-digit `event.staff_pin` and marks `is_redeemed = true` in Supabase.
  Future<({bool ok, String? error})> redeemPrize({
    required QuizEvent event,
    required QuizEventSubmission submission,
    required String deviceHash,
    required String staffPin,
  }) async {
    final entered = staffPin.trim();
    if (entered.isEmpty) {
      return (ok: false, error: 'INVALID_STAFF_PIN');
    }

    try {
      // Fetch latest staff_pin from quiz_events so live PIN updates take effect immediately
      String expectedPin = event.staffPin;
      final freshEvent = await _client
          .from('quiz_events')
          .select('staff_pin')
          .eq('id', event.id)
          .maybeSingle();
      if (freshEvent != null && freshEvent['staff_pin'] != null) {
        expectedPin = freshEvent['staff_pin'].toString().trim();
      }

      if (entered != expectedPin) {
        return (ok: false, error: 'INVALID_STAFF_PIN');
      }

      await _client
          .from('quiz_event_submissions')
          .update({'is_redeemed': true})
          .eq('id', submission.id);

      return (ok: true, error: null);
    } catch (_) {
      final res = await _client.rpc(
        'redeem_quiz_event_prize',
        params: {
          'p_submission_id': submission.id,
          'p_device_hash': deviceHash,
          'p_staff_pin': entered,
        },
      );
      if (res is Map && res['ok'] == true) {
        return (ok: true, error: null);
      }
      final err = res is Map ? res['error']?.toString() : 'UNKNOWN_ERROR';
      return (ok: false, error: err);
    }
  }

  // ===========================================================================
  // CATEGORY-FILTERED QUESTION LOADING (5 CATEGORIES / 98 QUESTIONS)
  // ===========================================================================

  /// Loads randomized questions:
  /// - Standard public quiz (`categories == null || categories.isEmpty`): across all 5 categories (98 questions).
  /// - Event quiz (`categories` non-empty): where `category = ANY(event.selected_categories)`.
  Future<List<QuizQuestionItem>> loadRandomizedQuestions({
    List<String>? categories,
    int count = 10,
  }) async {
    final filterCats = categories
        ?.map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    List<QuizQuestionItem> pool = [];

    // 1. Primary source: Supabase `quiz_questions` table
    try {
      final dynamic rows = (filterCats != null && filterCats.isNotEmpty)
          ? await _client
              .from('quiz_questions')
              .select()
              .inFilter('category', filterCats)
          : await _client.from('quiz_questions').select();

      if (rows is List && rows.isNotEmpty) {
        pool = rows
            .whereType<Map>()
            .map((r) => QuizQuestionItem.fromJson(Map<String, dynamic>.from(r)))
            .where(_isValidQuestion)
            .toList();
      }
    } catch (_) {}

    // 2. Fallback: Bundled 98-question 5-category seed asset (`assets/quiz/quiz_questions_seed_98.json`)
    if (pool.isEmpty) {
      final allSeed = await _loadBundledSeed98();
      if (filterCats != null && filterCats.isNotEmpty) {
        final allowed = filterCats.toSet();
        pool = allSeed.where((q) => allowed.contains(q.category)).toList();
      } else {
        pool = allSeed;
      }
    }

    pool.shuffle(_rng);
    final picked = pool.take(count).toList();
    return picked.map(_shuffleOptions).toList();
  }

  /// Queries distinct `category` values and question counts from `quiz_questions`.
  Future<List<QuizCategoryStat>> fetchCategoryStats() async {
    final Map<String, int> counts = {};

    try {
      final rows = await _client.from('quiz_questions').select('category');
      for (final row in rows) {
        final cat = (row['category'] ?? 'altalanos').toString().trim();
        final key = cat.isEmpty ? 'altalanos' : cat;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    } catch (_) {}

    if (counts.isEmpty) {
      final seed = await _loadBundledSeed98();
      for (final q in seed) {
        counts[q.category] = (counts[q.category] ?? 0) + 1;
      }
    }

    final orderedKeys = <String>[
      for (final k in kDefaultCategoryOrder)
        if (counts.containsKey(k)) k,
      ...counts.keys
          .where((k) => !kDefaultCategoryOrder.contains(k))
          .toList()
        ..sort(),
    ];

    return [
      for (final key in orderedKeys)
        QuizCategoryStat(category: key, count: counts[key] ?? 0),
    ];
  }

  Future<List<QuizQuestionItem>> _loadBundledSeed98() async {
    try {
      final raw = await rootBundle
          .loadString('assets/quiz/quiz_questions_seed_98.json');
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((q) => QuizQuestionItem.fromJson(Map<String, dynamic>.from(q)))
            .where(_isValidQuestion)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  bool _isValidQuestion(QuizQuestionItem q) =>
      q.question.isNotEmpty &&
      q.options.length >= 2 &&
      q.correctIndex >= 0 &&
      q.correctIndex < q.options.length;

  QuizQuestionItem _shuffleOptions(QuizQuestionItem item) {
    final indexed = [
      for (var i = 0; i < item.options.length; i++)
        (text: item.options[i], isCorrect: i == item.correctIndex),
    ]..shuffle(_rng);

    return QuizQuestionItem(
      id: item.id,
      question: item.question,
      options: [for (final entry in indexed) entry.text],
      correctIndex: indexed.indexWhere((entry) => entry.isCorrect),
      explanation: item.explanation,
      category: item.category,
    );
  }

  // ===========================================================================
  // ORGANIZER ADMIN EVENT MANAGER FLOW
  // ===========================================================================

  Future<List<QuizEvent>> listEventsWithMetrics() async {
    final eventRows = await _client
        .from('quiz_events')
        .select()
        .order('created_at', ascending: false);

    final events = [
      for (final r in eventRows)
        QuizEvent.fromJson(Map<String, dynamic>.from(r)),
    ];
    if (events.isEmpty) return const [];

    final subRows = await _client
        .from('quiz_event_submissions')
        .select(
          'id,event_id,started_at,completed_at,score,reward_code,is_redeemed',
        );

    final Map<String, List<Map<String, dynamic>>> subsByEvent = {};
    for (final raw in subRows) {
      final m = Map<String, dynamic>.from(raw);
      final evId = (m['event_id'] ?? '').toString();
      (subsByEvent[evId] ??= []).add(m);
    }

    return [
      for (final ev in events)
        _attachMetrics(ev, subsByEvent[ev.id] ?? const []),
    ];
  }

  QuizEvent _attachMetrics(
    QuizEvent ev,
    List<Map<String, dynamic>> submissions,
  ) {
    var started = 0;
    var completed = 0;
    var winners = 0;
    var redeemed = 0;

    for (final s in submissions) {
      started++;
      if (s['completed_at'] != null) {
        completed++;
        final sc = (s['score'] as num?)?.toInt() ?? 0;
        final hasCode =
            s['reward_code'] != null && s['reward_code'].toString().isNotEmpty;
        if (ev.hasConfiguredReward && (hasCode || sc >= ev.minScore)) {
          winners++;
        }
      }
      if (s['is_redeemed'] == true) {
        redeemed++;
      }
    }

    return ev.copyWithMetrics(
      startedCount: started,
      completedCount: completed,
      winnersCount: winners,
      redeemedCount: redeemed,
    );
  }

  Future<QuizEvent> createEvent({
    required String slug,
    required String title,
    required List<String> selectedCategories,
    required int questionCount,
    required int minScore,
    required bool rewardEnabled,
    required String rewardName,
    required String staffPin,
    bool isActive = true,
  }) async {
    final cats =
        selectedCategories.isEmpty ? const ['altalanos'] : selectedCategories;
    final effectiveEnabled = rewardEnabled && rewardName.trim().isNotEmpty;
    final cleanRewardName = effectiveEnabled ? rewardName.trim() : '';
    final row = await _client
        .from('quiz_events')
        .insert({
          'slug': slug.trim().toLowerCase(),
          'title': title.trim(),
          'selected_categories': cats,
          'is_active': isActive,
          'question_count': questionCount,
          'min_score': minScore,
          'reward_enabled': effectiveEnabled,
          'reward_name': cleanRewardName,
          'staff_pin': staffPin.trim().isEmpty ? '1234' : staffPin.trim(),
        })
        .select()
        .single();
    return QuizEvent.fromJson(Map<String, dynamic>.from(row));
  }

  Future<QuizEvent> updateEvent({
    required String id,
    required String slug,
    required String title,
    required List<String> selectedCategories,
    required int questionCount,
    required int minScore,
    required bool rewardEnabled,
    required String rewardName,
    required String staffPin,
    required bool isActive,
  }) async {
    final cats =
        selectedCategories.isEmpty ? const ['altalanos'] : selectedCategories;
    final effectiveEnabled = rewardEnabled && rewardName.trim().isNotEmpty;
    final cleanRewardName = effectiveEnabled ? rewardName.trim() : '';
    final row = await _client
        .from('quiz_events')
        .update({
          'slug': slug.trim().toLowerCase(),
          'title': title.trim(),
          'selected_categories': cats,
          'is_active': isActive,
          'question_count': questionCount,
          'min_score': minScore,
          'reward_enabled': effectiveEnabled,
          'reward_name': cleanRewardName,
          'staff_pin': staffPin.trim().isEmpty ? '1234' : staffPin.trim(),
        })
        .eq('id', id)
        .select()
        .single();
    return QuizEvent.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> toggleEventActive(String id, bool isActive) async {
    await _client
        .from('quiz_events')
        .update({'is_active': isActive}).eq('id', id);
  }

  Future<void> deleteEvent(String id) async {
    final deleted = await _client
        .from('quiz_events')
        .delete()
        .eq('id', id)
        .select('id');

    if (deleted.isNotEmpty) return;

    // Fallback to SECURITY DEFINER RPC if direct table RLS returned 0 rows
    final ok = await _client.rpc(
      'delete_quiz_event',
      params: {'p_event_id': id},
    );
    if (ok != true) {
      throw StateError(
        'Az esemény törlése nem sikerült (nincs jogosultság vagy már törölték).',
      );
    }
  }
}
