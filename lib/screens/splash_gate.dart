import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/auth_scene.dart';
import '../widgets/community_ui.dart';

import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  Future<void> _startTimer() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const SplashScreen();
    }

    return AuthGate(
      authService: AuthService(),
      postRepository: FirestorePostRepository(),
    );
  }
}

/// Shown while the app starts: the logo on violet (the native launch
/// screen shows the same, so there's no jump).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Color(0xFF7C3AED),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF7C3AED),
                  Color(0xFF8B5CF6),
                  Color(0xFFB9A2FB),
                ],
              ),
            ),
            child: SizedBox.expand(
              child: Center(
                child: Reveal(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(size: 140),
                      SizedBox(height: 8),
                      Text(
                        'Community',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Connect · Report · Shop · Thrive',
                        style: TextStyle(
                          color: Color(0xEBFFFFFF),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
