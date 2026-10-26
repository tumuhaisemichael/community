import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/beacon_mark.dart';
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

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.hero,
      body: Center(
        child: Reveal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeaconMark(size: 76, color: AppColors.accent, animate: true),
              const SizedBox(height: 28),
              Text(
                'Community',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 38,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Neighbours looking out for each other.',
                style: TextStyle(color: AppColors.heroMuted, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
