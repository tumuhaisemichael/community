import 'package:flutter/material.dart';

import 'app_theme.dart';

class ChatBackgroundPreset {
  const ChatBackgroundPreset({
    required this.key,
    required this.label,
    required this.colors,
    required this.darkColors,
  });

  final String key;
  final String label;
  final List<Color> colors;
  final List<Color> darkColors;

  List<Color> get currentColors => AppColors.isDark ? darkColors : colors;

  BoxDecoration decoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: currentColors,
      ),
    );
  }
}

class ChatBubblePreset {
  const ChatBubblePreset({
    required this.key,
    required this.label,
    required this.selfColor,
    required this.otherColor,
    required this.selfTextColor,
    required this.otherTextColor,
  });

  final String key;
  final String label;
  final Color selfColor;
  final Color otherColor;
  final Color selfTextColor;
  final Color otherTextColor;
}

class ChatAppearanceCatalog {
  static const backgrounds = <ChatBackgroundPreset>[
    ChatBackgroundPreset(
      key: 'linen',
      label: 'Classic',
      colors: [Color(0xFFF3F4F8), Color(0xFFEBEDF4)],
      darkColors: [Color(0xFF0C0F1E), Color(0xFF10142A)],
    ),
    ChatBackgroundPreset(
      key: 'mint',
      label: 'Mint',
      colors: [Color(0xFFE9F7F2), Color(0xFFD7EEE7)],
      darkColors: [Color(0xFF0B1A17), Color(0xFF0F231F)],
    ),
    ChatBackgroundPreset(
      key: 'sky',
      label: 'Sky',
      colors: [Color(0xFFEAF4FF), Color(0xFFDCEBFF)],
      darkColors: [Color(0xFF0B1424), Color(0xFF0F1B30)],
    ),
    ChatBackgroundPreset(
      key: 'sunset',
      label: 'Sunset',
      colors: [Color(0xFFFFF0E3), Color(0xFFF8D9C6)],
      darkColors: [Color(0xFF1E140E), Color(0xFF2A1B12)],
    ),
  ];

  static const bubbleThemes = <ChatBubblePreset>[
    ChatBubblePreset(
      key: 'community',
      label: 'Indigo',
      selfColor: Color(0xFF24306B),
      otherColor: Color(0xFFFFFFFF),
      selfTextColor: Colors.white,
      otherTextColor: Color(0xFF161C3A),
    ),
    ChatBubblePreset(
      key: 'ocean',
      label: 'Ocean',
      selfColor: Color(0xFF0C6E8A),
      otherColor: Color(0xFFEAF8FC),
      selfTextColor: Colors.white,
      otherTextColor: Color(0xFF134B5A),
    ),
    ChatBubblePreset(
      key: 'amber',
      label: 'Amber',
      selfColor: Color(0xFFB86B0D),
      otherColor: Color(0xFFFFF4DF),
      selfTextColor: Colors.white,
      otherTextColor: Color(0xFF6A4505),
    ),
    ChatBubblePreset(
      key: 'rose',
      label: 'Rose',
      selfColor: Color(0xFFB24A67),
      otherColor: Color(0xFFFFECF2),
      selfTextColor: Colors.white,
      otherTextColor: Color(0xFF6A2840),
    ),
  ];

  static ChatBackgroundPreset backgroundByKey(String key) {
    return backgrounds.firstWhere(
      (background) => background.key == key,
      orElse: () => backgrounds.first,
    );
  }

  /// In dark mode the other person's bubble uses the dark card colour so it
  /// never glows on a dark background.
  static ChatBubblePreset bubbleByKey(String key) {
    final preset = bubbleThemes.firstWhere(
      (theme) => theme.key == key,
      orElse: () => bubbleThemes.first,
    );
    if (!AppColors.isDark) return preset;
    return ChatBubblePreset(
      key: preset.key,
      label: preset.label,
      selfColor: preset.key == 'community'
          ? const Color(0xFF3A4BA8)
          : preset.selfColor,
      otherColor: AppColors.card,
      selfTextColor: preset.selfTextColor,
      otherTextColor: AppColors.ink,
    );
  }
}
