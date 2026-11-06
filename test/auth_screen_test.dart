import 'package:community/screens/auth_gate.dart';
import 'package:community/screens/auth_screen.dart';
import 'package:community/widgets/auth_scene.dart';
import 'package:community/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  String get uid => 'new-user';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthService {
  final signIns = <(String, String)>[];
  final signUps = <(String, String)>[];
  final resets = <String>[];
  bool wrongPassword = false;
  User? _user;

  @override
  User? get currentUser => _user;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signIns.add((email, password));
    if (wrongPassword) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    return _Credential();
  }

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signUps.add((email, password));
    _user = _User();
  }

  @override
  Future<void> sendPasswordReset(String email) async => resets.add(email);

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Credential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

Finder _field(String hint) => find.widgetWithText(TextFormField, hint);

void main() {
  testWidgets('Sign In: validation, wrong password, then success', (
    tester,
  ) async {
    final auth = _Auth()..wrongPassword = true;
    await _pump(tester, AuthScreen(authService: auth));

    expect(find.text('Community'), findsWidgets);
    expect(find.text('Connect · Report · Shop · Thrive'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(
      find.text('Welcome back! Sign in to your Community account.'),
      findsOneWidget,
    );

    // Empty form: nothing is sent.
    await tester.tap(find.bySemanticsLabel('Sign In').last);
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email.'), findsOneWidget);
    expect(auth.signIns, isEmpty);

    await tester.enterText(_field('Enter your email'), ' amina@mail.com ');
    await tester.enterText(_field('Enter your password'), 'secret1');
    await tester.tap(find.bySemanticsLabel('Sign In').last);
    await tester.pumpAndSettle();
    expect(auth.signIns.single, ('amina@mail.com', 'secret1'));
    expect(
      find.text('Wrong email or password. Please try again.'),
      findsOneWidget,
    );

    // Show / hide password.
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);

    auth.wrongPassword = false;
    await tester.tap(find.bySemanticsLabel('Sign In').last);
    await tester.pumpAndSettle();
    expect(auth.signIns.length, 2);
    expect(
      find.text('Wrong email or password. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('Google is shown but muted', (tester) async {
    await _pump(tester, AuthScreen(authService: _Auth()));
    expect(find.text('Continue with Google'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Continue with Google'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Forgot Password sends a reset link', (tester) async {
    final auth = _Auth();
    await _pump(tester, AuthScreen(authService: auth));
    await tester.enterText(_field('Enter your email'), 'amina@mail.com');
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    // The email typed on the form is filled in.
    await tester.tap(find.bySemanticsLabel('Send Reset Link'));
    await tester.pumpAndSettle();
    expect(auth.resets, ['amina@mail.com']);
    expect(find.text('Check your email'), findsOneWidget);
  });

  testWidgets('Create Account: checks fields, saves the name', (tester) async {
    final auth = _Auth();
    final saved = <String>[];
    await _pump(
      tester,
      AuthScreen(
        authService: auth,
        saveProfile: (user, name) async => saved.add('${user.uid}:$name'),
      ),
    );
    await tester.enterText(_field('Enter your email'), 'amina@mail.com');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Join your neighbours on Community.'), findsOneWidget);
    // The email carries over from Sign In.
    expect(find.text('amina@mail.com'), findsOneWidget);

    await tester.enterText(_field('Enter your full name'), 'Amina Nakato');
    await tester.enterText(_field('At least 6 characters'), 'secret1');
    await tester.enterText(_field('Enter your password again'), 'secret2');
    await tester.tap(find.bySemanticsLabel('Create Account').last);
    await tester.pumpAndSettle();
    expect(find.text('The passwords don\'t match.'), findsOneWidget);
    expect(auth.signUps, isEmpty);

    await tester.enterText(_field('Enter your password again'), 'secret1');
    await tester.tap(find.bySemanticsLabel('Create Account').last);
    await tester.pumpAndSettle();
    expect(auth.signUps.single, ('amina@mail.com', 'secret1'));
    expect(saved, ['new-user:Amina Nakato']);

    // Back to Sign In.
    await tester.tap(find.text('Sign In').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Welcome back! Sign in to your Community account.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('The violet header stays still while the form scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(authService: _Auth())),
    );
    await tester.pumpAndSettle();
    final logo = tester.getTopLeft(find.text('Community').first);
    final title = tester.getTopLeft(
      find.text('Welcome back! Sign in to your Community account.'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Community').first), logo);
    expect(
      tester
          .getTopLeft(
            find.text('Welcome back! Sign in to your Community account.'),
          )
          .dy,
      lessThan(title.dy),
    );

    // With the keyboard up, the header shrinks to a slim bar.
    final full = tester.getSize(find.byType(AuthScene)).height;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AuthScene)).height, lessThan(full - 150));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Start page: slides, Get Started, Sign In and back', (
    tester,
  ) async {
    await _pump(tester, SignedOutFlow(authService: _Auth()));
    expect(find.text('Community'), findsOneWidget);
    // Safety comes first, then the marketplace.
    for (final f in ['Report', 'Alerts', 'Map']) {
      expect(find.bySemanticsLabel(f), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);

    // Swipe to the next slide.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Buy'), findsOneWidget);

    // Get Started opens Create Account; back returns to the Start page.
    await tester.tap(find.bySemanticsLabel('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Join your neighbours on Community.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Get Started'), findsOneWidget);

    // Sign In opens Sign In; Create Account from there, back goes to Sign In.
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(
      find.text('Welcome back! Sign in to your Community account.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('Welcome back! Sign in to your Community account.'),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Get Started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
