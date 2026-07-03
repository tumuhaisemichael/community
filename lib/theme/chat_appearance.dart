import 'package:flutter/material.dart';

class ChatBackgroundPreset {
  const ChatBackgroundPreset({
    required this.key,
    required this.label,
    required this.colors,
  });

  final String key;
  final String label;
  final List<Color> colors;

  BoxDecoration decoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
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
      label: 'Linen',
      colors: [Color(0xFFF7F1E8), Color(0xFFEDE6DA)],
    ),
    ChatBackgroundPreset(
      key: 'mint',
      label: 'Mint',
      colors: [Color(0xFFE9F7F2), Color(0xFFD7EEE7)],
    ),
    ChatBackgroundPreset(
      key: 'sky',
      label: 'Sky',
      colors: [Color(0xFFEAF4FF), Color(0xFFDCEBFF)],
    ),
    ChatBackgroundPreset(
      key: 'sunset',
      label: 'Sunset',
      colors: [Color(0xFFFFF0E3), Color(0xFFF8D9C6)],
    ),
  ];

  static const bubbleThemes = <ChatBubblePreset>[
    ChatBubblePreset(
      key: 'community',
      label: 'Community',
      selfColor: Color(0xFF2F7D5D),
      otherColor: Color(0xFFFFFFFF),
      selfTextColor: Colors.white,
      otherTextColor: Color(0xFF27413A),
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

  static ChatBubblePreset bubbleByKey(String key) {
    return bubbleThemes.firstWhere(
      (theme) => theme.key == key,
      orElse: () => bubbleThemes.first,
    );
  }
}
