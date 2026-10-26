import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/community_post.dart';
import '../theme/app_theme.dart';
import 'community_ui.dart';

/// Top of the home tab: SOS, a summary of the last 24 hours nearby, and the
/// four most used shortcuts.
class HomeOverview extends StatelessWidget {
  const HomeOverview({
    super.key,
    required this.posts,
    required this.currentLocation,
    required this.onSosTap,
    required this.onSosTriggered,
    required this.onReport,
    required this.onVacation,
    required this.onEmergency,
    required this.onPolice,
    required this.onOpenMap,
  });

  final List<CommunityPost> posts;
  final LatLng? currentLocation;
  final VoidCallback onSosTap;
  final VoidCallback onSosTriggered;
  final VoidCallback onReport;
  final VoidCallback onVacation;
  final VoidCallback onEmergency;
  final VoidCallback onPolice;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Reveal(
        child: SosHoldButton(onTap: onSosTap, onTriggered: onSosTriggered),
      ),
      const SizedBox(height: 14),
      Reveal(
        order: 1,
        child: AreaPulseCard(
          posts: posts,
          currentLocation: currentLocation,
          onOpenMap: onOpenMap,
        ),
      ),
      const SizedBox(height: 18),
      Reveal(
        order: 2,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Shortcut(
              icon: Icons.report_gmailerrorred_rounded,
              label: 'Report',
              color: AppColors.amber,
              onTap: onReport,
            ),
            _Shortcut(
              icon: Icons.cottage_outlined,
              label: 'Vacation watch',
              onTap: onVacation,
            ),
            _Shortcut(
              icon: Icons.phone_in_talk_outlined,
              label: 'Emergency',
              onTap: onEmergency,
            ),
            _Shortcut(
              icon: Icons.local_police_outlined,
              label: 'Police',
              onTap: onPolice,
            ),
          ],
        ),
      ),
    ],
  );
}

/// "Your area · last 24 h" summary card.
class AreaPulseCard extends StatelessWidget {
  const AreaPulseCard({
    super.key,
    required this.posts,
    required this.currentLocation,
    required this.onOpenMap,
  });

  static const double radiusKm = 2;

  final List<CommunityPost> posts;
  final LatLng? currentLocation;
  final VoidCallback onOpenMap;

  List<CommunityPost> get _recent {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    const distance = Distance();
    final here = currentLocation;
    return posts.where((post) {
      if (post.createdAt.isBefore(since)) return false;
      if (here == null) return true;
      if (post.latitude == null || post.longitude == null) return false;
      final km = distance.as(
        LengthUnit.Kilometer,
        here,
        LatLng(post.latitude!, post.longitude!),
      );
      return km <= radiusKm;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recent;
    final serious = recent.where((p) => p.severity.isSerious).length;
    final counts = <PostCategory, int>{};
    for (final post in recent) {
      counts[post.category] = (counts[post.category] ?? 0) + 1;
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final (statusLabel, statusColor, statusText) = serious > 0
        ? ('Stay alert', AppColors.alert, Colors.white)
        : recent.isEmpty
        ? ('Quiet', AppColors.safe, Colors.white)
        : ('Calm', AppColors.accent, AppColors.onAccent);

    final scope = currentLocation == null
        ? 'Community · last 24 h'
        : 'Within ${radiusKm.toStringAsFixed(0)} km · last 24 h';
    final headline = recent.isEmpty
        ? 'No reports nearby'
        : '${recent.length} report${recent.length == 1 ? '' : 's'}'
              '${serious > 0 ? ', $serious urgent' : ''}';

    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.heroMuted,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w700,
    );

    return Material(
      color: AppColors.hero,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenMap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(scope.toUpperCase(), style: labelStyle)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                headline,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              if (top.isEmpty)
                Text(
                  currentLocation == null
                      ? 'Turn on location to see what is happening near you.'
                      : 'Tap to see neighbours and reports on the map.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.heroMuted),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in top.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${entry.value} ${entry.key.label.toLowerCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: color ?? AppColors.primary, size: 25),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
