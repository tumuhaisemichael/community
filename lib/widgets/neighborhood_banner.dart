import 'package:flutter/material.dart';
import 'community_ui.dart';

/// Shared page introduction used by the community and reporting flows.
class NeighborhoodBanner extends StatelessWidget {
  const NeighborhoodBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
  });
  final String title;
  final String subtitle;
  final String? eyebrow;
  @override
  Widget build(BuildContext context) =>
      PageIntro(title: title, subtitle: subtitle, eyebrow: eyebrow);
}
