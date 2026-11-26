import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_quiz_models.dart';

class EventQuizRepository {
  EventQuizRepository(this._client);

  final SupabaseClient _client;

  // ===========================================================================
  // PUBLIC / GUEST FLOW (via SECURITY DEFINER RPCs)
  // ===========================================================================

  Future<({QuizEvent? event, QuizEventSubmission? submission})>
      fetchPublicEventState({
    required String slug,
    required String deviceHash,
  }) async {
    final res = await _client.rpc(
      'get_public_quiz_event_state',
      params: {
        'p_slug': slug.trim().toLowerCase(),
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

  Future<QuizEventSubmission> startQuiz({
    required String eventId,
    required String deviceHash,
  }) async {
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

  Future<QuizEventSubmission> completeQuiz({
    required String eventId,
    required String deviceHash,
    required int score,
  }) async {
    final res = await _client.rpc(
      'complete_quiz_event_submission',
      params: {
        'p_event_id': eventId,
        'p_device_hash': deviceHash,
        'p_score': score,
      },
    );
    return QuizEventSubmission.fromJson(
      Map<String, dynamic>.from(res as Map),
    );
  }

  Future<({bool ok, String? error})> redeemPrize({
    required String submissionId,
    required String deviceHash,
    required String staffPin,
  }) async {
    final res = await _client.rpc(
      'redeem_quiz_event_prize',
      params: {
        'p_submission_id': submissionId,
        'p_device_hash': deviceHash,
        'p_staff_pin': staffPin.trim(),
      },
    );
    if (res is Map && res['ok'] == true) {
      return (ok: true, error: null);
    }
    final err = res is Map ? res['error']?.toString() : 'UNKNOWN_ERROR';
    return (ok: false, error: err);
  }

  Future<List<QuizQuestionItem>> loadRandomizedQuestions(int count) async {
    try {
      final rawJson = await rootBundle.loadString('portal/kiosk/questions.json');
      final decoded = jsonDecode(rawJson);
      if (decoded is List && decoded.isNotEmpty) {
        final bank = decoded
            .whereType<Map>()
            .map((q) => QuizQuestionItem.fromJson(Map<String, dynamic>.from(q)))
            .where((q) =>
                q.question.isNotEmpty &&
                q.choices.length >= 2 &&
                q.correctIndex >= 0 &&
                q.correctIndex < q.choices.length)
            .toList();
        bank.shuffle(Random());
        final picked = bank.take(count).toList();
        return picked.map(_shuffleChoices).toList();
      }
    } catch (_) {}

    // Safe built-in fallback questions if asset load fails
    final fallback = List<QuizQuestionItem>.from(_builtinFallbackQuestions)
      ..shuffle(Random());
    return fallback.take(count).map(_shuffleChoices).toList();
  }

  QuizQuestionItem _shuffleChoices(QuizQuestionItem item) {
    final indexed = [
      for (var i = 0; i < item.choices.length; i++)
        (text: item.choices[i], isCorrect: i == item.correctIndex),
    ]..shuffle(Random());

    return QuizQuestionItem(
      id: item.id,
      question: item.question,
      choices: [for (final entry in indexed) entry.text],
      correctIndex: indexed.indexWhere((entry) => entry.isCorrect),
      explanation: item.explanation,
      category: item.category,
    );
  }

  // ===========================================================================
  // ADMIN EVENT MANAGER FLOW
  // ===========================================================================

  Future<List<QuizEvent>> listEventsWithMetrics() async {
    final res = await _client.rpc('get_quiz_events_with_metrics');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((row) => QuizEvent.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }
    return const [];
  }

  Future<QuizEvent> createEvent({
    required String slug,
    required String title,
    required int questionCount,
    required int minScore,
    required String staffPin,
    bool isActive = true,
  }) async {
    final row = await _client
        .from('quiz_events')
        .insert({
          'slug': slug.trim().toLowerCase(),
          'title': title.trim(),
          'is_active': isActive,
          'question_count': questionCount,
          'min_score': minScore,
          'staff_pin': staffPin.trim().isEmpty ? '1234' : staffPin.trim(),
        })
        .select()
        .single();
    return QuizEvent.fromJson(row);
  }

  Future<QuizEvent> updateEvent({
    required String id,
    required String slug,
    required String title,
    required int questionCount,
    required int minScore,
    required String staffPin,
    required bool isActive,
  }) async {
    final row = await _client
        .from('quiz_events')
        .update({
          'slug': slug.trim().toLowerCase(),
          'title': title.trim(),
          'is_active': isActive,
          'question_count': questionCount,
          'min_score': minScore,
          'staff_pin': staffPin.trim().isEmpty ? '1234' : staffPin.trim(),
        })
        .eq('id', id)
        .select()
        .single();
    return QuizEvent.fromJson(row);
  }

  Future<void> toggleEventActive(String id, bool isActive) async {
    await _client
        .from('quiz_events')
        .update({'is_active': isActive}).eq('id', id);
  }

  Future<void> deleteEvent(String id) async {
    await _client.from('quiz_events').delete().eq('id', id);
  }
}

const List<QuizQuestionItem> _builtinFallbackQuestions = [
  QuizQuestionItem(
    id: 'FB-1',
    question: 'Melyik az egységes európai segélyhívó szám Magyarországon is?',
    choices: ['112', '911', '104'],
    correctIndex: 0,
    explanation:
        'A 112 a nap 24 órájában ingyenesen hívható egységes európai segélyhívó szám.',
    category: 'Általános felkészültség',
  ),
  QuizQuestionItem(
    id: 'FB-2',
    question: 'Mit teszel, ha egy serpenyőben ég a főzőolaj?',
    choices: [
      'Elzárod a hőt és fedővel letakarod; vizet tilos ráönteni!',
      'Hideg vizet öntesz rá a csapból.',
      'Kiviszed az égő serpenyőt a folyosóra.',
    ],
    correctIndex: 0,
    explanation:
        'Az égő olajra öntött víz robbanásszerű lángfellobbanást okoz!',
    category: 'Tűzvédelem',
  ),
  QuizQuestionItem(
    id: 'FB-3',
    question: 'Miért veszélyes a szén-monoxid (CO)?',
    choices: [
      'Színtelen, szagtalan, mérgező gáz, érzékszervekkel nem észlelhető.',
      'Erős szúrós szaga van, de nem mérgező.',
      'Csak nyáron keletkezhet elektromos tűz esetén.',
    ],
    correctIndex: 0,
    explanation:
        'A szén-monoxid érzékszervekkel nem ismerhető fel, ezért életmentő a minősített CO-érzékelő.',
    category: 'Áram-, gáz- és CO-veszély',
  ),
];
