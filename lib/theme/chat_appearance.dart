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

  /// The chat screen always uses the light versions of the backgrounds.
  BoxDecoration chatDecoration() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ),
  );

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

  /// Violet gradient for your own messages with the default theme.
  bool get usesGradient => key == 'community';
}

/// Colours for the chat screen (header, composer and other chrome).
class ChatTone {
  ChatTone._();

  static const Color header = Colors.white;
  static const Color composer = Colors.white;
  static const Color field = Color(0xFFF3F0FB);
  static const Color otherBubble = Color(0xFFF1EEFA);
  static const Color otherBorder = Color(0xFFE6E1F3);
  static const Color chip = Color(0xFFEFEBFA);
  static const Color text = Color(0xFF1E1240);
  static const Color muted = Color(0xFF6B6485);
  static const Color accent = Color(0xFF6D28D9);
  static const Color avatar = Color(0xFFEDE6FD);
  static const Color online = Color(0xFF22C55E);
  static const List<Color> selfGradient = [
    Color(0xFF7C3AED),
    Color(0xFF6D28D9),
  ];
}

class ChatAppearanceCatalog {
  static const backgrounds = <ChatBackgroundPreset>[
    ChatBackgroundPreset(
      key: 'linen',
      label: 'Classic',
      colors: [Color(0xFFFCFBFF), Color(0xFFF6F3FD)],
      darkColors: [Color(0xFF17152E), Color(0xFF0F0D20)],
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

  /// Bubble colours for the chat screen. The default theme uses a violet
  /// gradient for your messages and soft lavender for theirs.
  static ChatBubblePreset chatBubbleByKey(String key) {
    final preset = bubbleThemes.firstWhere(
      (theme) => theme.key == key,
      orElse: () => bubbleThemes.first,
    );
    if (preset.key != 'community') return preset;
    return ChatBubblePreset(
      key: preset.key,
      label: preset.label,
      selfColor: ChatTone.selfGradient.last,
      otherColor: ChatTone.otherBubble,
      selfTextColor: Colors.white,
      otherTextColor: ChatTone.text,
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
