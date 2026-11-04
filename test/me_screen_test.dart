import 'package:community/screens/settings_screen.dart';
import 'package:community/services/auth_service.dart';
import 'package:community/services/ui_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  String get uid => 'me';
  @override
  String? get displayName => 'Mic';
  @override
  String? get email => 'mic@example.com';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthService {
  int signOuts = 0;
  @override
  User? get currentUser => _User();
  @override
  Future<void> signOut() async => signOuts++;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  tearDown(() {
    final prefs = UiPreferences.instance;
    prefs.setAlertRadiusKm(2);
    prefs.setStartTab('home');
  });

  testWidgets('Me screen: profile, tools, preferences and log out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = _Auth();
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            authService: auth,
            profile: Stream.value({'isVerified': true}),
            tools: [
              for (final (icon, title) in const [
                (Icons.cottage_outlined, 'Vacation watch'),
                (Icons.campaign_outlined, 'Community bulletin'),
                (Icons.groups_outlined, 'Neighbour directory'),
                (Icons.edit_note_outlined, 'My safety log'),
                (Icons.bar_chart_rounded, 'Crime stats'),
                (Icons.info_outline_rounded, 'About & guidelines'),
              ])
                SettingsTool(
                  icon: icon,
                  title: title,
                  subtitle: '',
                  onTap: () => opened.add(title),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verified Neighbour'), findsOneWidget);
    expect(find.text('Safety & Community Tools'), findsOneWidget);

    // "About" is a link further down, not a tile.
    await tester.tap(find.text('About & Guidelines'));
    expect(opened, ['About & guidelines']);

    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();
    expect(find.text('About & guidelines'), findsOneWidget);
    await tester.tap(find.text('Crime stats').last);
    await tester.pumpAndSettle();
    expect(opened.last, 'Crime stats');

    // Alert radius slider changes the radius used across the app.
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(UiPreferences.instance.alertRadiusKm, greaterThan(2));

    // Home Screen → Map.
    await tester.tap(find.text('Home Screen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(UiPreferences.instance.startTab, 'map');
    expect(find.text('Opens on Map'), findsOneWidget);

    // Log out asks first.
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 1);
    expect(tester.takeException(), isNull);
  });
}
