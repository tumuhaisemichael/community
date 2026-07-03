import 'package:flutter/material.dart';

import '../screens/splash_gate.dart';
import '../theme/app_theme.dart';

class CommunityApp extends StatelessWidget {
  const CommunityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashGate(),
    );
  }
}