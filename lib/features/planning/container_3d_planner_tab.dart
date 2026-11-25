import 'package:flutter/material.dart';

import 'container_3d_planner_stub.dart'
    if (dart.library.js_interop) 'container_3d_planner_web.dart';
import 'planning_repository.dart';

class Container3DPlannerTab extends StatelessWidget {
  const Container3DPlannerTab({
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
    return Container3DPlannerTabImpl(
      exerciseId: exerciseId,
      exerciseTitle: exerciseTitle,
      repository: repository,
      onSavingChanged: onSavingChanged,
    );
  }
}
