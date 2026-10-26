import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  final List<({IconData icon, String title, String content})> tips = const [
    (
      icon: Icons.lock_outline_rounded,
      title: 'Secure your home',
      content:
          'Lock all doors and windows before leaving or going to sleep. Use '
          'deadbolts for extra security.',
    ),
    (
      icon: Icons.groups_outlined,
      title: 'Know your neighbours',
      content:
          'A street where people know each other notices when something is '
          'wrong. Say hello and swap numbers.',
    ),
    (
      icon: Icons.medical_services_outlined,
      title: 'Be ready for emergencies',
      content:
          'Keep emergency numbers saved on your phone (Police 999, Ambulance '
          '912) and a basic first-aid kit at home.',
    ),
    (
      icon: Icons.visibility_outlined,
      title: 'Report anything unusual',
      content:
          'Early reports help neighbours stay alert and can prevent crime. '
          'If in doubt, report it.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Safety tips')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const PageIntro(
            'Simple habits that keep you and your neighbours safer.',
          ),
          for (final tip in tips)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(icon: tip.icon, color: AppColors.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tip.title, style: textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(tip.content, style: textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
