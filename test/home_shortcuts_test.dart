import 'package:community/services/ui_preferences.dart';
import 'package:community/widgets/home_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _overview() => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HomeOverview(
        posts: const [],
        currentLocation: null,
        onSosTap: () {},
        onSosTriggered: () {},
        onReport: () {},
        onVacation: () {},
        onEmergency: () {},
        onPolice: () {},
        onOpenMap: () {},
      ),
    ),
  ),
);

double _x(WidgetTester tester, String label) =>
    tester.getCenter(find.text(label).last).dx;

void main() {
  tearDown(() => UiPreferences.instance.setMoveShortcuts(true));

  testWidgets('Shortcuts shift one place every 5 seconds', (tester) async {
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    final reportX = _x(tester, 'Report');
    final policeX = _x(tester, 'Police');
    expect(reportX, lessThan(policeX));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    // Report wrapped round to the last slot; Police moved one to the left.
    expect(_x(tester, 'Report'), closeTo(policeX, 1));
    expect(_x(tester, 'Police'), lessThan(policeX));
  });

  testWidgets('Turning the setting off stops and resets them', (tester) async {
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    final reportX = _x(tester, 'Report');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    UiPreferences.instance.setMoveShortcuts(false);
    await tester.pumpAndSettle();
    expect(_x(tester, 'Report'), closeTo(reportX, 1));

    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    expect(_x(tester, 'Report'), closeTo(reportX, 1));
  });

  testWidgets('Five shortcuts keep their size and scroll sideways', (
    tester,
  ) async {
    UiPreferences.instance.setMoveShortcuts(false);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: HomeOverview(
              posts: const [],
              currentLocation: null,
              onSosTap: () {},
              onSosTriggered: () {},
              onReport: () {},
              onVacation: () {},
              onMarketplace: () {},
              onEmergency: () {},
              onPolice: () {},
              onOpenMap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Same width as when four fit across: (358 − 3 × 10) / 4 = 82.
    final tile = tester.getRect(
      find.byType(InkWell).at(find.byType(InkWell).evaluate().length - 5),
    );
    expect(tile.width, closeTo(82, 1));

    // The fifth tile starts off-screen and is reached by swiping.
    expect(tester.getCenter(find.text('Police').last).dx, greaterThan(390));
    await tester.drag(find.text('Market place').last, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('Police').last).dx, lessThan(390));
  });
}
