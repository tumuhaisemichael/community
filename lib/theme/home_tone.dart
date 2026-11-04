import 'package:flutter/material.dart';

import '../models/community_post.dart';

/// White-and-violet palette for the home tab and the bottom bar.
///
/// The home tab always uses this light look, even when the phone is in dark
/// mode.
class HomeTone {
  HomeTone._();

  static const Color violet = Color(0xFF6D28D9);
  static const Color violetDim = Color(0xFFF0EAFE);
  static const Color canvas = Color(0xFFFCFBFF);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFEDE9F6);
  static const Color ink = Color(0xFF1E1240);
  static const Color muted = Color(0xFF6B6485);
  static const Color skeleton = Color(0xFFEFECF6);

  static const Color red = Color(0xFFE5383B);
  static const Color redDim = Color(0xFFFDECEC);
  static const Color orange = Color(0xFFF26B1D);
  static const Color yellow = Color(0xFFE6A700);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueDim = Color(0xFFE8EFFE);
  static const Color green = Color(0xFF1F8A5B);
  static const Color greenDim = Color(0xFFE3F5EC);

  static const Color noticeBg = Color(0xFFFFF7E6);
  static const Color noticeBorder = Color(0xFFF7E3B5);
  static const Color noticeIcon = Color(0xFFE08A00);

  static const List<Color> headerGradient = [
    Color(0xFF5B21B6),
    Color(0xFF7C3AED),
    Color(0xFFA78BFA),
  ];

  static const List<Color> sosGradient = [Color(0xFFF2545B), Color(0xFFD62839)];

  static const List<Color> actionGradient = [
    Color(0xFF8B5CF6),
    Color(0xFF6D28D9),
  ];

  /// Soft shadow that lifts white cards off the white background.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF4C1D95).withValues(alpha: .06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Severity colours for the home feed: violet → yellow → orange → red.
  static Color severity(PostSeverity severity) => switch (severity) {
    PostSeverity.low => violet,
    PostSeverity.medium => yellow,
    PostSeverity.high => orange,
    PostSeverity.critical => red,
  };
}
