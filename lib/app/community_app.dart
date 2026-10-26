import 'package:flutter/material.dart';

import '../screens/splash_gate.dart';
import '../theme/app_theme.dart';

class CommunityApp extends StatefulWidget {
  const CommunityApp({super.key});

  @override
  State<CommunityApp> createState() => _CommunityAppState();
}

class _CommunityAppState extends State<CommunityApp>
    with WidgetsBindingObserver {
  Brightness _brightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppColors.apply(_brightness);
    // Many widgets read AppColors directly (including const subtrees), so the
    // whole tree is rebuilt under a new key when the system theme flips.
    return MaterialApp(
      key: ValueKey(_brightness),
      title: 'Community',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      home: const SplashGate(),
    );
  }
}
