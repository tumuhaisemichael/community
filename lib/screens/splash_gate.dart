import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';

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

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: const Center(
        child: Reveal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_outlined, color: AppColors.lime, size: 64),
              SizedBox(height: 24),
              Text(
                'Community',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'A little closer. A little safer.',
                style: TextStyle(color: Color(0xFFC7D9CE), fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
