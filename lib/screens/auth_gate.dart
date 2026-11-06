import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'splash_gate.dart';
import 'welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.postRepository,
  });

  final AuthService authService;
  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData) {
          return HomeScreen(
            authService: authService,
            postRepository: postRepository,
          );
        }

        return SignedOutFlow(authService: authService);
      },
    );
  }
}

/// Signed out: the Start page, then Sign In or Create Account. Kept in one
/// widget (not pushed routes) so nothing is left above Home after signing
/// in.
class SignedOutFlow extends StatefulWidget {
  const SignedOutFlow({super.key, required this.authService});
  final AuthService authService;

  @override
  State<SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<SignedOutFlow> {
  /// null: the Start page; true: Create Account; false: Sign In.
  bool? _signUp;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    child: _signUp == null
        ? WelcomeScreen(
            key: const ValueKey('start'),
            onGetStarted: () => setState(() => _signUp = true),
            onSignIn: () => setState(() => _signUp = false),
          )
        : AuthScreen(
            key: ValueKey(_signUp),
            authService: widget.authService,
            startWithSignUp: _signUp!,
            onBack: () => setState(() => _signUp = null),
          ),
  );
}
