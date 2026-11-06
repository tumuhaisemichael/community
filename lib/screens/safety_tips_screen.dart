import 'package:flutter/material.dart';

import '../theme/home_tone.dart';
import '../widgets/page_frame.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  final List<({IconData icon, String title, String content, Color color})>
  tips = const [
    (
      icon: Icons.lock_outline_rounded,
      title: 'Secure your home',
      content:
          'Lock all doors and windows before leaving or going to sleep. Use '
          'deadbolts for extra security.',
      color: HomeTone.violet,
    ),
    (
      icon: Icons.groups_outlined,
      title: 'Know your neighbours',
      content:
          'A street where people know each other notices when something is '
          'wrong. Say hello and swap numbers.',
      color: HomeTone.blue,
    ),
    (
      icon: Icons.medical_services_outlined,
      title: 'Be ready for emergencies',
      content:
          'Keep emergency numbers saved on your phone (Police 999, Ambulance '
          '912) and a basic first-aid kit at home.',
      color: HomeTone.red,
    ),
    (
      icon: Icons.visibility_outlined,
      title: 'Report anything unusual',
      content:
          'Early reports help neighbours stay alert and can prevent crime. '
          'If in doubt, report it.',
      color: HomeTone.green,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Safety Tips',
      subtitle: 'Simple habits that keep you and your neighbours safer.',
      badge: const _TipBadge(),
      children: [
        for (final (i, tip) in tips.indexed)
          FrameCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tip.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(tip.icon, color: tip.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tip ${i + 1}',
                        style: TextStyle(
                          color: tip.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        tip.title,
                        style: const TextStyle(
                          color: HomeTone.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip.content,
                        style: const TextStyle(
                          color: HomeTone.muted,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TipBadge extends StatelessWidget {
  const _TipBadge();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.lightbulb_outline_rounded,
        color: Colors.white,
        size: 30,
      ),
    ),
  );
}
