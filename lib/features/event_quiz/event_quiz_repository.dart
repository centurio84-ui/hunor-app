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

  /// Upserts a row with `started_at = now()` and `participant_name` on `(event_id, device_hash)`.
  /// If an incomplete row existed from an earlier visit, resets `started_at` to `now()` so completion speed is accurate!
  Future<QuizEventSubmission> startQuiz({
    required String eventId,
    required String deviceHash,
    String? participantName,
  }) async {
    final cleanName = participantName?.trim();
    final effectiveName =
        (cleanName != null && cleanName.isNotEmpty) ? cleanName : null;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    try {
      final existing = await _client
          .from('quiz_event_submissions')
          .select()
          .eq('event_id', eventId)
          .eq('device_hash', deviceHash)
          .maybeSingle();

      if (existing != null) {
        final existingSub = QuizEventSubmission.fromJson(
          Map<String, dynamic>.from(existing),
        );
        if (existingSub.isCompleted) {
          return existingSub;
        }
        // Incomplete earlier attempt -> refresh started_at & participant_name for accurate speed timing
        final payload = <String, dynamic>{
          'started_at': nowIso,
          if (effectiveName != null) 'participant_name': effectiveName,
        };
        try {
          final updated = await _client
              .from('quiz_event_submissions')
              .update(payload)
              .eq('id', existingSub.id)
              .select()
              .single();
          return QuizEventSubmission.fromJson(
            Map<String, dynamic>.from(updated),
          );
        } catch (_) {
          // Fallback if participant_name column was not yet migrated
          final updated = await _client
              .from('quiz_event_submissions')
              .update({'started_at': nowIso})
              .eq('id', existingSub.id)
              .select()
              .single();
          return QuizEventSubmission.fromJson(
            Map<String, dynamic>.from(updated),
          );
        }
      }

      try {
        final inserted = await _client
            .from('quiz_event_submissions')
            .upsert(
              {
                'event_id': eventId,
                'device_hash': deviceHash,
                'started_at': nowIso,
                if (effectiveName != null) 'participant_name': effectiveName,
              },
              onConflict: 'event_id,device_hash',
            )
            .select()
            .single();

        return QuizEventSubmission.fromJson(Map<String, dynamic>.from(inserted));
      } catch (_) {
        final inserted = await _client
            .from('quiz_event_submissions')
            .upsert(
              {
                'event_id': eventId,
                'device_hash': deviceHash,
                'started_at': nowIso,
              },
              onConflict: 'event_id,device_hash',
            )
            .select()
            .single();

        return QuizEventSubmission.fromJson(Map<String, dynamic>.from(inserted));
      }
    } catch (_) {
      final res = await _client.rpc(
        'start_quiz_event_submission',
        params: {
          'p_event_id': eventId,
          'p_device_hash': deviceHash,
          if (effectiveName != null) 'p_participant_name': effectiveName,
        },
      );
      return QuizEventSubmission.fromJson(
        Map<String, dynamic>.from(res as Map),
      );
    }
  }

  /// Marks submission completed (`completed_at = now()`, `score`, `participant_name`, `duration_ms`).
  Future<QuizEventSubmission> completeQuiz({
    required QuizEvent event,
    required String deviceHash,
    required int score,
    String? participantName,
    int? durationMs,
  }) async {
    final cleanName = participantName?.trim();
    final effectiveName =
        (cleanName != null && cleanName.isNotEmpty) ? cleanName : null;

    try {
      final existingRow = await _client
          .from('quiz_event_submissions')
          .select()
          .eq('event_id', event.id)
          .eq('device_hash', deviceHash)
          .maybeSingle();

      DateTime? startedAt;
      if (existingRow != null) {
        final existingSub = QuizEventSubmission.fromJson(
          Map<String, dynamic>.from(existingRow),
        );
        if (existingSub.isCompleted) {
          return existingSub;
        }
        startedAt = existingSub.startedAt;
      }

      final completedNow = DateTime.now().toUtc();
      final completedIso = completedNow.toIso8601String();
      final computedMs = durationMs ??
          (startedAt != null
              ? completedNow
                  .difference(startedAt.toUtc())
                  .inMilliseconds
                  .clamp(1000, 3600000)
              : null);

      final bool won = event.hasConfiguredReward && score >= event.minScore;
      String? rewardCode;

      for (var attempt = 0; attempt < 15; attempt++) {
        rewardCode = won ? _generateRewardCode(attempt) : null;
        try {
          if (existingRow != null) {
            Map<String, dynamic> updated;
            try {
              updated = Map<String, dynamic>.from(
                await _client
                    .from('quiz_event_submissions')
                    .update({
                      'completed_at': completedIso,
                      'score': score,
                      'reward_code': rewardCode,
                      if (effectiveName != null)
                        'participant_name': effectiveName,
                      if (computedMs != null) 'duration_ms': computedMs,
                    })
                    .eq('id', existingRow['id'].toString())
                    .select()
                    .single(),
              );
            } catch (innerErr) {
              final msg = innerErr.toString().toLowerCase();
              if (won && msg.contains('reward_code')) rethrow;
              updated = Map<String, dynamic>.from(
                await _client
                    .from('quiz_event_submissions')
                    .update({
                      'completed_at': completedIso,
                      'score': score,
                      'reward_code': rewardCode,
                    })
                    .eq('id', existingRow['id'].toString())
                    .select()
                    .single(),
              );
            }
            return QuizEventSubmission.fromJson(updated);
          } else {
            Map<String, dynamic> inserted;
            try {
              inserted = Map<String, dynamic>.from(
                await _client
                    .from('quiz_event_submissions')
                    .insert({
                      'event_id': event.id,
                      'device_hash': deviceHash,
                      'started_at': completedIso,
                      'completed_at': completedIso,
                      'score': score,
                      'reward_code': rewardCode,
                      if (effectiveName != null)
                        'participant_name': effectiveName,
                      if (computedMs != null) 'duration_ms': computedMs,
                    })
                    .select()
                    .single(),
              );
            } catch (innerErr) {
              final msg = innerErr.toString().toLowerCase();
              if (won && msg.contains('reward_code')) rethrow;
              inserted = Map<String, dynamic>.from(
                await _client
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
                    .single(),
              );
            }
            return QuizEventSubmission.fromJson(inserted);
          }
        } catch (err) {
          final msg = err.toString().toLowerCase();
          if (won && msg.contains('reward_code')) {
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
          if (effectiveName != null) 'p_participant_name': effectiveName,
          if (durationMs != null) 'p_duration_ms': durationMs,
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
      final numPart = 100 + _rng.nextInt(900);
      return 'KUPON-$numPart';
    }
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final suffix = List.generate(
      4,
      (_) => chars[_rng.nextInt(chars.length)],
    ).join();
    return 'KUPON-$suffix';
  }

  /// Validates `event.staff_pin` and marks `is_redeemed = true` in Supabase.
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

  Future<List<QuizQuestionItem>> loadRandomizedQuestions({
    List<String>? categories,
    int count = 10,
  }) async {
    final filterCats = categories
        ?.map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    List<QuizQuestionItem> pool = [];

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
  // ORGANIZER ADMIN EVENT MANAGER FLOW & HOURLY LEADER NOTIFICATIONS
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

    List<dynamic> subRows;
    try {
      subRows = await _client.from('quiz_event_submissions').select(
            'id,event_id,participant_name,started_at,completed_at,duration_ms,score,reward_code,is_redeemed',
          );
    } catch (_) {
      subRows = await _client.from('quiz_event_submissions').select(
            'id,event_id,started_at,completed_at,score,reward_code,is_redeemed',
          );
    }

    final Map<String, List<Map<String, dynamic>>> subsByEvent = {};
    for (final raw in subRows) {
      final m = Map<String, dynamic>.from(raw as Map);
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

    final nowUtc = DateTime.now().toUtc();
    final oneHourAgo = nowUtc.subtract(const Duration(hours: 1));
    final List<QuizLeaderEntry> allCompleted = [];
    final List<QuizLeaderEntry> recentHourCompleted = [];

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

        final compAt =
            DateTime.tryParse(s['completed_at'].toString())?.toUtc() ?? nowUtc;
        final startAt =
            DateTime.tryParse((s['started_at'] ?? '').toString())?.toUtc() ??
                compAt;
        final rawDur = (s['duration_ms'] as num?)?.toInt();
        final durMs = (rawDur != null && rawDur > 0)
            ? rawDur
            : compAt.difference(startAt).inMilliseconds.clamp(1000, 3600000);
        final rawName = s['participant_name']?.toString().trim();
        final name = (rawName != null && rawName.isNotEmpty)
            ? rawName
            : 'Névtelen kitöltő';

        final entry = QuizLeaderEntry(
          submissionId: (s['id'] ?? '').toString(),
          participantName: name,
          score: sc,
          durationMs: durMs,
          completedAt: compAt,
        );
        allCompleted.add(entry);
        if (compAt.isAfter(oneHourAgo)) {
          recentHourCompleted.add(entry);
        }
      }
      if (s['is_redeemed'] == true) {
        redeemed++;
      }
    }

    int compareLeaders(QuizLeaderEntry a, QuizLeaderEntry b) {
      final scoreCmp = b.score.compareTo(a.score); // Higher score first
      if (scoreCmp != 0) return scoreCmp;
      final durCmp = a.durationMs.compareTo(b.durationMs); // Faster time first
      if (durCmp != 0) return durCmp;
      return a.completedAt.compareTo(b.completedAt); // Earlier completion first
    }

    allCompleted.sort(compareLeaders);
    recentHourCompleted.sort(compareLeaders);

    return ev.copyWithMetrics(
      startedCount: started,
      completedCount: completed,
      winnersCount: winners,
      redeemedCount: redeemed,
      topLeaders: allCompleted.take(10).toList(),
      lastHourLeader:
          recentHourCompleted.isNotEmpty ? recentHourCompleted.first : null,
      lastHourCompletions: recentHourCompleted.length,
    );
  }

  /// Checks & emits hourly leader notifications (for completed clock hours, or on-demand if `forceNow == true`),
  /// and returns the latest notifications list.
  Future<({List<QuizHourlyNotification> recent, List<QuizHourlyNotification> newlyEmitted})>
      syncAndFetchHourlyNotifications({bool forceNow = false}) async {
    final List<QuizHourlyNotification> newlyEmitted = [];
    try {
      final dynamic emittedRes = await _client.rpc(
        'check_and_emit_quiz_hourly_leaders',
        params: {'p_force_current_hour': forceNow},
      );
      if (emittedRes is List) {
        for (final item in emittedRes) {
          if (item is Map) {
            newlyEmitted.add(
              QuizHourlyNotification.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
    } catch (_) {}

    List<QuizHourlyNotification> recent = const [];
    try {
      final rows = await _client
          .from('quiz_event_hourly_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      recent = [
        for (final r in rows)
          QuizHourlyNotification.fromJson(Map<String, dynamic>.from(r)),
      ];
    } catch (_) {}

    return (recent: recent, newlyEmitted: newlyEmitted);
  }

  Future<QuizEvent> createEvent({
    required String slug,
    required String title,
    required List<String> selectedCategories,
    required int questionCount,
    required int minScore,
    required bool rewardEnabled,
    required String rewardName,
    required bool requireParticipantName,
    required bool hourlyLeaderNotify,
    required String staffPin,
    bool isActive = true,
  }) async {
    final cats =
        selectedCategories.isEmpty ? const ['altalanos'] : selectedCategories;
    final effectiveEnabled = rewardEnabled && rewardName.trim().isNotEmpty;
    final cleanRewardName = effectiveEnabled ? rewardName.trim() : '';
    final payload = <String, dynamic>{
      'slug': slug.trim().toLowerCase(),
      'title': title.trim(),
      'selected_categories': cats,
      'is_active': isActive,
      'question_count': questionCount,
      'min_score': minScore,
      'reward_enabled': effectiveEnabled,
      'reward_name': cleanRewardName,
      'require_participant_name': requireParticipantName,
      'hourly_leader_notify': hourlyLeaderNotify,
      'staff_pin': staffPin.trim().isEmpty ? '1234' : staffPin.trim(),
    };
    try {
      final row =
          await _client.from('quiz_events').insert(payload).select().single();
      return QuizEvent.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      payload
        ..remove('require_participant_name')
        ..remove('hourly_leader_notify');
      final row =
          await _client.from('quiz_events').insert(payload).select().single();
      return QuizEvent.fromJson(Map<String, dynamic>.from(row));
    }
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
    required bool requireParticipantName,
    required bool hourlyLeaderNotify,
    required String staffPin,
    required bool isActive,
  }) async {
    final cats =
        selectedCategories.isEmpty ? const ['altalanos'] : selectedCategories;
    final effectiveEnabled = rewardEnabled && rewardName.trim().isNotEmpty;
    final cleanRewardName = effectiveEnabled ? rewardName.trim() : '';
    final payload = <String, dynamic>{
      'slug': slug.trim().toLowerCase(),
      'title': title.trim(),
      'selected_categories': cats,
      'is_active': isActive,
      'question_count': questionCount,
      'min_score': minScore,
      'reward_enabled': effectiveEnabled,
      'reward_name': cleanRewardName,
      'require_participant_name': requireParticipantName,
      'hourly_leader_notify': hourlyLeaderNotify,
      'staff_pin': staffPin.trim().isEmpty ? '1234' : staffPin.trim(),
    };
    try {
      final row = await _client
          .from('quiz_events')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return QuizEvent.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      payload
        ..remove('require_participant_name')
        ..remove('hourly_leader_notify');
      final row = await _client
          .from('quiz_events')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return QuizEvent.fromJson(Map<String, dynamic>.from(row));
    }
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
