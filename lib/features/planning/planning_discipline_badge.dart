import 'package:flutter/material.dart';

import 'planning_models.dart';

Color planningDisciplineColor(BubbleDiscipline type) => switch (type) {
      BubbleDiscipline.checkpoint => const Color(0xffe8b665),
      BubbleDiscipline.custom => const Color(0xffb7c7d4),
      BubbleDiscipline.medical => const Color(0xffff9ca2),
      BubbleDiscipline.ucc => const Color(0xff94d9ee),
      BubbleDiscipline.pressVip => const Color(0xffd8b2fd),
    };

class PlanningDisciplineBadge extends StatelessWidget {
  const PlanningDisciplineBadge(this.discipline, {super.key});

  final BubbleDiscipline discipline;

  @override
  Widget build(BuildContext context) {
    final color = planningDisciplineColor(discipline);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          discipline.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}
