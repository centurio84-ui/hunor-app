import 'package:flutter/material.dart';

import 'planning_repository.dart';

class Container3DPlannerTabImpl extends StatelessWidget {
  const Container3DPlannerTabImpl({
    super.key,
    this.exerciseId,
    this.exerciseTitle,
    this.repository,
    this.onSavingChanged,
  });

  final String? exerciseId;
  final String? exerciseTitle;
  final PlanningRepository? repository;
  final ValueChanged<bool>? onSavingChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.view_in_ar_rounded, size: 44),
                const SizedBox(height: 12),
                Text(
                  '3D Konténerváz tervező',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Az interaktív 3D konténerváz tervező a webes böngészős felületen (hun01usar.hu/planning/) érhető el.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
