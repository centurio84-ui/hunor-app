import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../models/excon_evaluation.dart';
import '../models/excon_category_summary.dart';
import '../models/participant_evaluation.dart';

class ExconRepository {
  final SupabaseClient _client;
  static const String _offlineExconKey = 'hunor_offline_excon_evaluations';
  static const String _offlinePartKey = 'hunor_offline_participant_evaluations';

  ExconRepository({SupabaseClient? client})
      : _client = client ?? _resolveClient();

  static SupabaseClient _resolveClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
      );
    }
  }

  /// Értékelés beküldése az excon_evaluations táblába vagy helyi offline tárolóba
  Future<ExconEvaluation> submitEvaluation(ExconEvaluation evaluation) async {
    // Mindig mentsük el azonnal a helyi biztonsági tárolóba is adatvesztés ellen
    await _saveEvaluationLocally(evaluation);

    try {
      final jsonPayload = evaluation.toJson();
      // Ha id nincs megadva, ne küldjünk null értéket
      jsonPayload.remove('id');

      final response = await _client
          .from('excon_evaluations')
          .insert(jsonPayload)
          .select()
          .single();

      return ExconEvaluation.fromJson(response);
    } catch (e) {
      debugPrint('Supabase mentés sikertelen (offline tároló aktív): $e');
      // Offline fallback: helyileg már el van mentve, sikeresként adjuk vissza
      return evaluation;
    }
  }

  /// Kategóriánkénti összegzés lekérése
  Future<List<ExconCategorySummary>> fetchCategorySummaries() async {
    try {
      final response = await _client
          .from('excon_category_summary')
          .select()
          .order('performance_percentage', ascending: false);

      final list = response as List<dynamic>;
      return list
          .map((item) => ExconCategorySummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Kategória összegzés távoli lekérés hiba, helyi számítás: $e');
      return _computeLocalCategorySummaries();
    }
  }

  /// Beavatkozói önértékelés (T0 vagy T1) beküldése
  Future<ParticipantEvaluation> submitParticipantEvaluation(ParticipantEvaluation evaluation) async {
    await _saveParticipantEvaluationLocally(evaluation);

    try {
      final jsonPayload = evaluation.toJson();
      jsonPayload.remove('id');

      final response = await _client
          .from('participant_evaluations')
          .insert(jsonPayload)
          .select()
          .single();

      return ParticipantEvaluation.fromJson(response);
    } catch (e) {
      debugPrint('Önértékelés távoli mentés sikertelen (offline tároló aktív): $e');
      return evaluation;
    }
  }

  // --- Offline tároló segédfüggvények ---

  Future<void> _saveEvaluationLocally(ExconEvaluation evaluation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getLocalEvaluations();
      // Keressük meg, hogy volt-e már korábbi válasz erre az ellenőrzőpontra
      final filtered = currentList.where((e) =>
          !(e.checkpointCode == evaluation.checkpointCode &&
              e.evaluatorName == evaluation.evaluatorName)).toList();
      filtered.add(evaluation);

      final jsonStrings = filtered.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_offlineExconKey, jsonStrings);
    } catch (e) {
      debugPrint('Helyi mentés hiba: $e');
    }
  }

  Future<List<ExconEvaluation>> getLocalEvaluations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_offlineExconKey) ?? [];
      return rawList.map((str) {
        final Map<String, dynamic> map = jsonDecode(str) as Map<String, dynamic>;
        return ExconEvaluation.fromJson(map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveParticipantEvaluationLocally(ParticipantEvaluation evaluation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_offlinePartKey) ?? [];
      rawList.add(jsonEncode(evaluation.toJson()));
      await prefs.setStringList(_offlinePartKey, rawList);
    } catch (e) {
      debugPrint('Helyi önértékelés mentés hiba: $e');
    }
  }

  Future<List<ExconCategorySummary>> _computeLocalCategorySummaries() async {
    final localList = await getLocalEvaluations();
    if (localList.isEmpty) return [];

    final Map<String, List<int>> catScores = {};
    for (final ev in localList) {
      String cat = ev.checkpointCode;
      if (cat.startsWith('OP-K9')) {
        cat = 'OP-K9';
      } else if (cat.startsWith('III/C')) {
        cat = 'III/C';
      } else if (cat.contains('-')) {
        cat = cat.split('-').first;
      } else if (cat.contains('/')) {
        cat = cat.split('/').first;
      }

      catScores.putIfAbsent(cat, () => []).add(ev.score);
    }

    return catScores.entries.map((entry) {
      final count = entry.value.length;
      final maxScore = count * 2;
      final totalScore = entry.value.fold<int>(0, (a, b) => a + b);
      final pct = maxScore > 0 ? (totalScore / maxScore) * 100.0 : 0.0;
      return ExconCategorySummary(
        categoryCode: entry.key,
        evaluationCount: count,
        maxPossibleScore: maxScore,
        totalAchievedScore: totalScore,
        performancePercentage: pct,
      );
    }).toList();
  }
}
