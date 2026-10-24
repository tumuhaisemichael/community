import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  final List<Map<String, String>> tips = const [
    {
      'title': 'Secure Your Home',
      'content':
          'Ensure all doors and windows are locked before leaving or sleeping. Use deadbolts for extra security.',
    },
    {
      'title': 'Neighborhood Watch',
      'content':
          'Get to know your neighbors. A community that looks out for each other is a safer community.',
    },
    {
      'title': 'Emergency Preparedness',
      'content':
          'Keep a list of emergency numbers handy and have a basic first-aid kit in your home.',
    },
    {
      'title': 'Report Suspicious Activity',
      'content':
          'Don\'t hesitate to report anything unusual. Early reporting can prevent crimes.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Tips & Resources')),
      body: ListView.builder(
        padding: const EdgeInsets.all(22),
        itemCount: tips.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const PageIntro(
              title: 'Small habits. Safer days.',
              subtitle:
                  'Practical ways to look out for yourself and your neighbors.',
              eyebrow: 'Safety Tips & Resources',
              icon: Icons.lightbulb_outline_rounded,
            );
          }
          final tip = tips[index - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0$index',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.watch,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    tip['title']!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(tip['content']!),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
