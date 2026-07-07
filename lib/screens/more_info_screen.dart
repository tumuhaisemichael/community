import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'community_bulletin_screen.dart';
import 'emergency_contacts_screen.dart';
import 'neighbor_directory_screen.dart';
import 'police_locator_screen.dart';
import 'safety_log_screen.dart';
import 'statistics_dashboard_screen.dart';
import 'vacation_watch_screen.dart';

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

  Future<T?> _openScreen<T>(BuildContext context, Widget screen) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        icon: Icons.info_outline,
        title: 'About Community',
        content:
            'Community is a space for neighbors and members to share updates, '
            'learn from each other, and build local connections.',
      ),
      (
        icon: Icons.rule_outlined,
        title: 'Community Guidelines',
        content:
            'Be respectful, avoid harmful language, protect personal privacy, '
            'and keep discussions helpful and inclusive for everyone.',
      ),
      (
        icon: Icons.help_outline,
        title: 'Help',
        content:
            'Use the links below to open the main community tools. For direct support, '
            'contact the app owner or support team while in-app support grows.',
      ),
    ];

    final links = [
      (
        icon: Icons.campaign_outlined,
        title: 'Community Bulletin',
        subtitle: 'See all updates and announcements',
        onTap: () => _openScreen(
          context,
          CommunityBulletinScreen(
            authService: authService,
            postRepository: postRepository,
          ),
        ),
      ),
      (
        icon: Icons.shield_moon_outlined,
        title: 'Vacation Watch',
        subtitle: 'Create watch plans and claim shifts',
        onTap: () =>
            _openScreen(context, VacationWatchScreen(authService: authService)),
      ),
      (
        icon: Icons.groups_outlined,
        title: 'Neighbor Directory',
        subtitle: 'See community members and verified neighbors',
        onTap: () => _openScreen(context, const NeighborDirectoryScreen()),
      ),
      (
        icon: Icons.phone_in_talk_outlined,
        title: 'Emergency Contacts',
        subtitle: 'Important local numbers in one place',
        onTap: () => _openScreen(context, const EmergencyContactsScreen()),
      ),
      (
        icon: Icons.local_police_outlined,
        title: 'Find Police',
        subtitle: 'Open nearby station details and location',
        onTap: () => _openScreen(
          context,
          PoliceStationLocatorScreen(userLocation: currentLocation),
        ),
      ),
      (
        icon: Icons.edit_note_outlined,
        title: 'Safety Log',
        subtitle: 'Review your own reported incidents',
        onTap: () => _openScreen(
          context,
          SafetyLogScreen(
            authService: authService,
            postRepository: postRepository,
          ),
        ),
      ),
      (
        icon: Icons.bar_chart_outlined,
        title: 'Crime Stats',
        subtitle: 'View trends and neighborhood insights',
        onTap: () => _openScreen(
          context,
          StatisticsDashboardScreen(postRepository: postRepository),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More Info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.watch, AppColors.ink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Guide',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'This page gathers the support, guidance, and safety links that already exist in the app so they are easy to reach from one place.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...sections.map(
            (section) => Container(
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
                      Icon(section.icon, color: AppColors.watch),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          section.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    section.content,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Community links',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...links.map(
            (link) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(link.icon, color: AppColors.watch),
                title: Text(link.title),
                subtitle: Text(link.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: link.onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
