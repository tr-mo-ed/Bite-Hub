import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitehub_app/app/presentation/screens/auth/welcome_screen.dart';

void main() {
  testWidgets('Welcome screen renders primary actions', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(),
      ),
    );

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNWidgets(2));
    expect(find.byIcon(Icons.language), findsOneWidget);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
  });
}


