import 'package:flutter/material.dart';

import 'container_3d_planner_stub.dart'
    if (dart.library.js_interop) 'container_3d_planner_web.dart';

class Container3DPlannerTab extends StatelessWidget {
  const Container3DPlannerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Container3DPlannerTabImpl();
  }
}
