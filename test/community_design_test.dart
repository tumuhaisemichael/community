import 'package:community/screens/emergency_contacts_screen.dart';
import 'package:community/widgets/neighborhood_banner.dart';
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
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: HomeOverview(
                  greeting: 'Good morning, neighbor',
                  onAround: () => invoked.add('around'),
                  onSos: () => invoked.add('sos'),
                  onReport: () => invoked.add('report'),
                  onVacation: () => invoked.add('vacation'),
                  onMessages: () => invoked.add('messages'),
                  onBulletin: () => invoked.add('bulletin'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Explore around you',
        'Need help right now?',
        'Report Incident',
        'Vacation watch',
        'Messages',
        'Bulletin board',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(invoked, [
        'around',
        'sos',
        'report',
        'vacation',
        'messages',
        'bulletin',
      ]);
    },
  );

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
      MaterialApp(theme: AppTheme.light, home: const PrivacyControlsScreen()),
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

  testWidgets('Neighborhood header fits a small screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: const SingleChildScrollView(
              child: NeighborhoodBanner(
                eyebrow: 'Good morning, neighbor',
                title: 'Your neighborhood',
                subtitle: 'Your neighborhood at a glance.',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Your neighborhood'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SOS opens the existing confirmation action only when tapped', (
    tester,
  ) async {
    var confirmations = 0;
    await tester.pumpWidget(
      MaterialApp(home: EmergencyContactsScreen(onSos: () => confirmations++)),
    );
    expect(confirmations, 0);
    await tester.tap(find.text('Send Alert'));
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
