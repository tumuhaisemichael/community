import 'package:flutter/material.dart';

import '../screens/splash_gate.dart';
import '../services/ui_preferences.dart';
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
    return ListenableBuilder(
      listenable: UiPreferences.instance,
      builder: (context, _) {
        final prefs = UiPreferences.instance;
        // Me → App Appearance can override the phone's light/dark setting.
        final brightness = switch (prefs.themeMode) {
          'light' => Brightness.light,
          'dark' => Brightness.dark,
          _ => _brightness,
        };
        AppColors.apply(brightness);
        // Many widgets read AppColors directly (including const subtrees),
        // so the whole tree is rebuilt under a new key when the theme flips.
        return MaterialApp(
          key: ValueKey(brightness),
          title: 'Community',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current,
          // Me → Font Size scales text on every screen, on top of the
          // phone's own text size.
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final system = media.textScaler.scale(1);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(system * prefs.textScale),
              ),
              child: child!,
            );
          },
          home: const SplashGate(),
        );
      },
    );
  }
}
