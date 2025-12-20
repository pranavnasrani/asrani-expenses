// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:asrani_expenses/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // Build our app with showOnboarding set to false for testing
    await tester.pumpWidget(const MyApp(showOnboarding: false));

    // Verify the app launches (looking for loading indicator or login screen)
    expect(find.byType(MyApp), findsOneWidget);
  });
}
