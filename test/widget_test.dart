import 'package:flutter_test/flutter_test.dart';

import 'package:hunor_app/main.dart';

void main() {
  testWidgets('HUNOR app starts', (tester) async {
    await tester.pumpWidget(const HunorApp());
    expect(find.byType(HunorApp), findsOneWidget);
  });
}
