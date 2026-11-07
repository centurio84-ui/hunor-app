import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/api/mock_rescue_platform_api.dart';
import 'package:hunor_app/views/organization_switcher_view.dart';

void main() {
  testWidgets('OrganizationSwitcherView megjeleníti a szervezeteket mock API-val', (tester) async {
    final mockApi = MockRescuePlatformApi();

    await tester.pumpWidget(
      MaterialApp(
        home: OrganizationSwitcherView(api: mockApi),
      ),
    );

    // Várakozás a jövőbeli hívások (Future) lefutására
    await tester.pumpAndSettle();

    // Ellenőrizzük a fejlécet és a mock szervezeteket
    expect(find.text('Szervezetválasztó'), findsOneWidget);
    expect(find.text('HUNOR Mentőszervezet'), findsOneWidget);
    expect(find.text('Barlangi Mentőszolgálat'), findsOneWidget);
  });
}
