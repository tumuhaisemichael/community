import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:community/screens/splash_gate.dart';

void main() {
  testWidgets('Splash screen appears first', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    expect(find.text('Community'), findsOneWidget);
  });
}
