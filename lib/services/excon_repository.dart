import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../models/excon_evaluation.dart';
import '../models/excon_category_summary.dart';
import '../models/participant_evaluation.dart';

class ExconRepository {
  final SupabaseClient _client;

  ExconRepository({SupabaseClient? client})
      : _client = client ?? _resolveClient();

  static SupabaseClient _resolveClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // Ha még nem volt Supabase.initialize meghívva, a projekt beállításaiból inicializáljuk
      return SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
      );
    }
  }

  /// Értékelés beküldése az excon_evaluations táblába
  Future<ExconEvaluation> submitEvaluation(ExconEvaluation evaluation) async {
    try {
      final response = await _client
          .from('excon_evaluations')
          .insert(evaluation.toJson())
          .select()
          .single();

      return ExconEvaluation.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Adatbázis hiba: ${e.message}');
    } catch (e) {
      throw Exception('Hiba történt az értékelés mentésekor: $e');
    }
  }

  /// Kategóriánkénti összegzés lekérése az excon_category_summary SQL View-ból
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
    } on PostgrestException catch (e) {
      throw Exception('Adatbázis hiba az összegzés lekérésekor: ${e.message}');
    } catch (e) {
      throw Exception('Nem sikerült betölteni az összegzéseket: $e');
    }
  }

  /// Beavatkozói önértékelés (T0 vagy T1) beküldése
  Future<ParticipantEvaluation> submitParticipantEvaluation(ParticipantEvaluation evaluation) async {
    try {
      final response = await _client
          .from('participant_evaluations')
          .insert(evaluation.toJson())
          .select()
          .single();

      return ParticipantEvaluation.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Adatbázis hiba az önértékelés mentésekor: ${e.message}');
    } catch (e) {
      throw Exception('Hiba történt az önértékelés mentésekor: $e');
    }
  }
}
