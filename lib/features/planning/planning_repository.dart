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
    return rows
        .where((row) => row['is_active'] != false)
        .map(InsaragCheckpoint.fromJson)
        .toList();
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

  Future<Set<String>> fetchExercisePlanners(String exerciseId) async {
    try {
      final rows = await _client
          .from('exercise_planners')
          .select('member_id')
          .eq('exercise_id', exerciseId);
      return {
        for (final row in rows)
          if (row['member_id'] != null) row['member_id'].toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> setExercisePlanners({
    required String exerciseId,
    required Set<String> previousIds,
    required Set<String> nextIds,
    String? assignedBy,
  }) async {
    final toAdd = nextIds.difference(previousIds);
    final toRemove = previousIds.difference(nextIds);
    if (toRemove.isNotEmpty) {
      await _client
          .from('exercise_planners')
          .delete()
          .eq('exercise_id', exerciseId)
          .inFilter('member_id', toRemove.toList());
    }
    if (toAdd.isNotEmpty) {
      await _client.from('exercise_planners').insert([
        for (final memberId in toAdd)
          {
            'exercise_id': exerciseId,
            'member_id': memberId,
            if (assignedBy != null) 'assigned_by': assignedBy,
          },
      ]);
    }
  }

  Future<ExerciseDetails> fetchExerciseDetails(String exerciseId) async {
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
    String? sectorId,
    String? checkpointId,
    BubbleDiscipline discipline = BubbleDiscipline.custom,
    double? estimatedHours,
    Map<String, dynamic> specs = const {},
  }) async {
    final row = await _client
        .from('exercise_bubbles')
        .insert({
          'exercise_id': exerciseId,
          'sector_id': sectorId,
          'checkpoint_id': checkpointId,
          if (discipline != BubbleDiscipline.custom &&
              discipline != BubbleDiscipline.checkpoint)
            'bubble_type': discipline.value,
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
  }) =>
      _updateBubble(exerciseId, bubbleId, {
        'sector_id': sectorId,
        'estimated_hours': estimatedHours,
        'title': title.trim(),
        'specs': specs,
      });

  Future<ExerciseBubble> updateBubbleDetails({
    required ExerciseBubble bubble,
    BubbleDiscipline? discipline,
    required double? estimatedHours,
    required String title,
    required Map<String, dynamic> specs,
  }) =>
      _updateBubble(bubble.exerciseId, bubble.id, {
        if (discipline != null && discipline != bubble.discipline)
          'bubble_type': discipline.value,
        'estimated_hours': estimatedHours,
        'title': title.trim(),
        'specs': specs,
      });

  Future<ExerciseBubble> moveBubble(
    ExerciseBubble bubble,
    String? sectorId,
  ) =>
      _updateBubble(bubble.exerciseId, bubble.id, {'sector_id': sectorId});

  Future<ExerciseBubble> _updateBubble(
    String exerciseId,
    String bubbleId,
    Map<String, dynamic> changes,
  ) async {
    final row = await _client
        .from('exercise_bubbles')
        .update(changes)
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

  Future<ExerciseSector> createSector(
    String exerciseId, {
    String? name,
    String icmsName = '',
    String description = '',
  }) async {
    final params = <String, dynamic>{
      'p_exercise_id': exerciseId,
      if (name != null && name.trim().isNotEmpty) 'p_name': name.trim(),
      if (icmsName.trim().isNotEmpty) 'p_icms_name': icmsName.trim(),
      if (description.trim().isNotEmpty) 'p_description': description.trim(),
    };
    final row = await _client
        .rpc('create_planning_sector', params: params)
        .single();
    return ExerciseSector.fromJson(row);
  }

  Future<ExerciseSector> updateSector({
    required String exerciseId,
    required String sectorId,
    required String name,
    required String icmsName,
    required String description,
  }) async {
    final row = await _client
        .from('exercise_sectors')
        .update({
          'name': name.trim(),
          'icms_name': icmsName.trim(),
          'description': description.trim(),
        })
        .eq('exercise_id', exerciseId)
        .eq('id', sectorId)
        .select()
        .single();
    return ExerciseSector.fromJson(row);
  }

  Future<void> deleteSector({
    required String exerciseId,
    required String sectorId,
  }) async {
    await _client
        .from('exercise_sectors')
        .delete()
        .eq('exercise_id', exerciseId)
        .eq('id', sectorId)
        .select('id')
        .single();
  }

  Future<List<ExerciseTimelineBlock>> fetchTimeline(String exerciseId) async {
    try {
      final rows = await _client
          .from('exercise_timeline_blocks')
          .select()
          .eq('exercise_id', exerciseId)
          .order('planned_start_hour', ascending: true)
          .order('id', ascending: true);
      return rows.map(ExerciseTimelineBlock.fromJson).toList();
    } on PostgrestException catch (error) {
      if (error.code == '42P01' || error.code == 'PGRST205') {
        throw const PlanningTimelineUnavailable();
      }
      rethrow;
    }
  }

  Future<ExerciseTimelineBlock> addTimelineBlock({
    required ExerciseBubble bubble,
    required String? sectorId,
    required TimelineTiming timing,
    required String notes,
  }) async {
    final row = await _client
        .from('exercise_timeline_blocks')
        .insert({
          'exercise_id': bubble.exerciseId,
          'bubble_id': bubble.id,
          'sector_id': sectorId,
          'planned_start_hour': timing.start,
          'planned_duration_hours': timing.duration,
          'notes': notes,
        })
        .select()
        .single();
    return ExerciseTimelineBlock.fromJson(row);
  }

  Future<ExerciseTimelineBlock> updatePlannedTimeline({
    required ExerciseTimelineBlock block,
    required String? sectorId,
    required TimelineTiming timing,
    required String notes,
  }) =>
      _updateTimeline(block, {
        'sector_id': sectorId,
        'planned_start_hour': timing.start,
        'planned_duration_hours': timing.duration,
        'notes': notes,
      });

  Future<ExerciseTimelineBlock> updateActualTimeline({
    required ExerciseTimelineBlock block,
    required TimelineTiming timing,
    required TimelineStatus status,
  }) =>
      _updateTimeline(block, {
        'actual_start_hour': timing.start,
        'actual_duration_hours': timing.duration,
        'status': status.value,
      });

  Future<ExerciseTimelineBlock> copyTimelineToActual(
    ExerciseTimelineBlock block, {
    required bool overwrite,
  }) async {
    final row = await _client.rpc('copy_planning_block_to_actual', params: {
      'p_exercise_id': block.exerciseId,
      'p_block_id': block.id,
      'p_overwrite': overwrite,
    }).single();
    return ExerciseTimelineBlock.fromJson(row);
  }

  Future<void> deleteTimelineBlock(ExerciseTimelineBlock block) async {
    await _client
        .from('exercise_timeline_blocks')
        .delete()
        .eq('exercise_id', block.exerciseId)
        .eq('id', block.id)
        .select('id')
        .single();
  }

  Future<ExerciseTimelineBlock> _updateTimeline(
    ExerciseTimelineBlock block,
    Map<String, dynamic> changes,
  ) async {
    final row = await _client
        .from('exercise_timeline_blocks')
        .update(changes)
        .eq('exercise_id', block.exerciseId)
        .eq('id', block.id)
        .select()
        .single();
    return ExerciseTimelineBlock.fromJson(row);
  }
}

class PlanningTimelineUnavailable implements Exception {
  const PlanningTimelineUnavailable();
}
