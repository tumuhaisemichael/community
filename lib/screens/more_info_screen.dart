import 'package:flutter/material.dart';
import '../widgets/community_ui.dart';
import 'package:latlong2/latlong.dart';

import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class MoreInfoScreen extends StatelessWidget {
  const MoreInfoScreen({
    super.key,
    required this.authService,
    required this.postRepository,
    this.currentLocation,
  });

  final AuthService authService;
  final PostRepository postRepository;
  final LatLng? currentLocation;

  static const _guidelines = [
    'Be respectful. No insults, threats or hate speech.',
    'Report facts you saw or heard, not rumours.',
    'Protect privacy. Do not post photos of children, or anyone’s phone '
        'number or address.',
    'Never use the SOS button as a test or a joke.',
    'In an emergency, call 999 first.',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    Widget section(IconData icon, String title, Widget body) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: icon, size: 38, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('About & guidelines')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const PageIntro(
            'How Community works and what we expect from every member.',
          ),
          section(
            Icons.info_outline_rounded,
            'About Community',
            Text(
              'Community helps neighbours in Kampala share safety updates, '
              'report incidents, and look after each other’s homes. Reports '
              'come from members like you, so they are only as good as what '
              'people share.',
              style: textTheme.bodyMedium,
            ),
          ),
          section(
            Icons.rule_rounded,
            'Community guidelines',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rule in _guidelines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: AppColors.safe,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(rule, style: textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          section(
            Icons.help_outline_rounded,
            'Need help?',
            Text(
              'Use Feedback & support on the Me tab to report a problem or '
              'flag a post. Moderators review flagged posts.',
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
