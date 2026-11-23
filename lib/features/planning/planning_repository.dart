import 'package:supabase_flutter/supabase_flutter.dart';

import 'planning_models.dart';

class PlanningRepository {
  const PlanningRepository(this._client, {required this.organizationId});

  final SupabaseClient _client;
  final String organizationId;

  Future<List<InsaragCheckpoint>> fetchCheckpointCatalog() async {
    final rows = await _client
        .from('insarag_checkpoint_catalog')
        .select()
        .order('sort_order', ascending: true)
        .order('id', ascending: true);
    return rows.map(InsaragCheckpoint.fromJson).toList();
  }

  Future<List<Exercise>> listExercises() async {
    final rows = await _client
        .from('exercises')
        .select()
        .eq('organization_id', organizationId)
        .order('created_at')
        .order('id');
    return rows.map(Exercise.fromJson).toList();
  }

  Future<Exercise> createExercise(String title) async {
    final row = await _client
        .from('exercises')
        .insert({'organization_id': organizationId, 'title': title.trim()})
        .select()
        .single();
    return Exercise.fromJson(row);
  }

  Future<({List<ExerciseSector> sectors, List<ExerciseBubble> bubbles})>
      fetchExerciseDetails(String exerciseId) async {
    final results = await Future.wait([
      _client
          .from('exercise_sectors')
          .select()
          .eq('exercise_id', exerciseId)
          .order('number', ascending: true),
      _client
          .from('exercise_bubbles')
          .select()
          .eq('exercise_id', exerciseId)
          .order('created_at', ascending: true)
          .order('id', ascending: true),
    ]);
    return (
      sectors: results[0].map(ExerciseSector.fromJson).toList(),
      bubbles: results[1].map(ExerciseBubble.fromJson).toList(),
    );
  }

  Future<ExerciseBubble> addBubble({
    required String exerciseId,
    required String title,
    String? checkpointId,
    double? estimatedHours,
    Map<String, dynamic> specs = const {},
  }) async {
    final row = await _client
        .from('exercise_bubbles')
        .insert({
          'exercise_id': exerciseId,
          'sector_id': null,
          'checkpoint_id': checkpointId,
          'estimated_hours': estimatedHours,
          'title': title.trim(),
          'specs': specs,
        })
        .select()
        .single();
    return ExerciseBubble.fromJson(row);
  }

  Future<ExerciseBubble> updateBubble({
    required String exerciseId,
    required String bubbleId,
    required String? sectorId,
    required double? estimatedHours,
    required String title,
    required Map<String, dynamic> specs,
  }) async {
    final row = await _client
        .from('exercise_bubbles')
        .update({
          'sector_id': sectorId,
          'estimated_hours': estimatedHours,
          'title': title.trim(),
          'specs': specs,
        })
        .eq('exercise_id', exerciseId)
        .eq('id', bubbleId)
        .select()
        .single();
    return ExerciseBubble.fromJson(row);
  }

  Future<void> deleteBubble({
    required String exerciseId,
    required String bubbleId,
  }) async {
    await _client
        .from('exercise_bubbles')
        .delete()
        .eq('exercise_id', exerciseId)
        .eq('id', bubbleId)
        .select('id')
        .single();
  }

  Future<ExerciseSector> createSector(String exerciseId) async {
    final row = await _client.rpc('create_planning_sector',
        params: {'p_exercise_id': exerciseId}).single();
    return ExerciseSector.fromJson(row);
  }
}
