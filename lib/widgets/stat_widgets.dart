import 'package:flutter/material.dart';

import '../theme/home_tone.dart';

/// White tile with an icon, a big number and a label.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    // Its own item for screen readers, not merged with its neighbours.
    container: true,
    label: '$value $label',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: HomeTone.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeTone.border),
        boxShadow: HomeTone.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (color ?? HomeTone.violet).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: color ?? HomeTone.violet),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color ?? HomeTone.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(color: HomeTone.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

/// Rounded filter chip: filled violet when selected.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? HomeTone.violet : HomeTone.card,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? HomeTone.violet : HomeTone.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : HomeTone.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

/// White panel with an icon, title and message, for empty states.
class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HomeTone.border),
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: HomeTone.violetDim,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: HomeTone.violet, size: 28),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: HomeTone.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: HomeTone.muted, fontSize: 13),
        ),
      ],
    ),
  );
}
