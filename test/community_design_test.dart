import 'package:community/screens/emergency_contacts_screen.dart';
import 'package:flutter/material.dart';
import 'package:community/theme/app_theme.dart';
import 'package:community/widgets/community_ui.dart';
import 'package:community/widgets/home_overview.dart';
import 'package:community/screens/privacy_controls_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Home actions fit narrow screens with large text and retain every callback',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final invoked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.current,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: HomeOverview(
                  posts: const [],
                  currentLocation: null,
                  onSosTap: () => invoked.add('sos'),
                  onSosTriggered: () => invoked.add('sos-sent'),
                  onOpenMap: () => invoked.add('map'),
                  onReport: () => invoked.add('report'),
                  onVacation: () => invoked.add('vacation'),
                  onEmergency: () => invoked.add('emergency'),
                  onPolice: () => invoked.add('police'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Hold 2 seconds to send SOS',
        'No reports nearby',
        'Report',
        'Vacation watch',
        'Emergency',
        'Police',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(invoked, [
        'sos',
        'map',
        'report',
        'vacation',
        'emergency',
        'police',
      ]);
    },
  );

  testWidgets('SOS sends only after a full two-second hold', (tester) async {
    var sent = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SosHoldButton(onTap: () {}, onTriggered: () => sent++),
        ),
      ),
    );
    final button = find.byType(SosHoldButton);

    final short = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await short.up();
    await tester.pumpAndSettle();
    expect(sent, 0);

    final long = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await long.up();
    await tester.pumpAndSettle();
    expect(sent, 1);
  });

  testWidgets('Entrance effects respect reduced motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Reveal(child: Text('Visible immediately')),
        ),
      ),
    );
    expect(find.text('Visible immediately'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('Restyled privacy switches still respond independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.current, home: const PrivacyControlsScreen()),
    );
    await tester.pumpAndSettle();
    final email = find.widgetWithText(SwitchListTile, 'Show email address');
    expect(tester.widget<SwitchListTile>(email).value, false);
    await tester.ensureVisible(email);
    await tester.tap(email);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(email).value, true);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Show approximate location'),
          )
          .value,
      true,
    );
  });

  testWidgets('SOS opens the existing confirmation action only when tapped', (
    tester,
  ) async {
    var confirmations = 0;
    await tester.pumpWidget(
      MaterialApp(home: EmergencyContactsScreen(onSos: () => confirmations++)),
    );
    expect(confirmations, 0);
    await tester.tap(find.text('Send SOS alert'));
    expect(confirmations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Every existing emergency contact and call action remains accessible',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: EmergencyContactsScreen()),
      );
      for (final contact in const EmergencyContactsScreen().contacts) {
        await tester.scrollUntilVisible(find.text(contact['name']!), 120);
        expect(find.byTooltip('Call ${contact['name']}'), findsOneWidget);
        expect(find.text(contact['number']!), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
