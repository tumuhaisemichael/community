import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../theme/home_tone.dart';
import 'community_ui.dart';

/// "12 min ago", "3 hr ago", "2 d ago".
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays} d ago';
}

/// "~350 m away", "~1.2 km away".
String distanceLabel(double km) => km < 1
    ? '~${(km * 1000 / 50).round() * 50} m away'
    : '~${km.toStringAsFixed(1)} km away';

/// One report in a list: severity bar, category icon, text and a trailing
/// widget such as the time or a chevron.
class ReportRow extends StatelessWidget {
  const ReportRow({
    super.key,
    required this.post,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final CommunityPost post;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = HomeTone.severity(post.severity);
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(categoryIcon(post.category), color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: HomeTone.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: HomeTone.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}
