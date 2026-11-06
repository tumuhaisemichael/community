import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import '../theme/home_tone.dart';
import '../widgets/page_frame.dart';

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
    const body = TextStyle(color: HomeTone.ink, fontSize: 14, height: 1.45);
    return PageFrame(
      title: 'About & Guidelines',
      subtitle: 'How Community works and what we expect from every member.',
      children: [
        const FrameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FrameCardTitle(
                icon: Icons.info_outline_rounded,
                title: 'About Community',
              ),
              SizedBox(height: 12),
              Text(
                'Community helps neighbours in Kampala share safety updates, '
                'report incidents, and look after each other’s homes. Reports '
                'come from members like you, so they are only as good as what '
                'people share.',
                style: body,
              ),
            ],
          ),
        ),
        FrameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FrameCardTitle(
                icon: Icons.rule_rounded,
                title: 'Community guidelines',
                color: HomeTone.green,
              ),
              const SizedBox(height: 12),
              for (final (i, rule) in _guidelines.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: HomeTone.greenDim,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: HomeTone.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(rule, style: body)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const FrameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FrameCardTitle(
                icon: Icons.help_outline_rounded,
                title: 'Need help?',
                color: HomeTone.blue,
              ),
              SizedBox(height: 12),
              Text(
                'Use Feedback & Support on the Me tab to report a problem, or '
                'flag a post from its ⋯ menu. Moderators review flagged posts.',
                style: body,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
