import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';
import '../models/community_post.dart';
import '../repositories/post_repository.dart';

class StatisticsDashboardScreen extends StatelessWidget {
  const StatisticsDashboardScreen({super.key, required this.postRepository});
  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crime stats')),
      body: StreamBuilder<List<CommunityPost>>(
        stream: postRepository.getPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  SkeletonBox(height: 96, radius: 18),
                  SizedBox(height: 16),
                  SkeletonBox(height: 260, radius: 18),
                ],
              ),
            );
          }

          final posts = (snapshot.data ?? [])
              .where((p) => p.category != PostCategory.general)
              .toList();
          if (posts.isEmpty) {
            return const EmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'No incidents yet',
              message: 'Stats appear once neighbours start reporting.',
            );
          }

          final weekAgo = DateTime.now().subtract(const Duration(days: 7));
          final lastWeek = posts.where((p) => p.createdAt.isAfter(weekAgo));
          final serious = posts.where((p) => p.severity.isSerious).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              const PageIntro(
                'Incidents reported by the community. General updates are '
                'not counted.',
              ),
              Row(
                children: [
                  _StatTile(label: 'All time', value: posts.length),
                  const SizedBox(width: 10),
                  _StatTile(label: 'Last 7 days', value: lastWeek.length),
                  const SizedBox(width: 10),
                  _StatTile(
                    label: 'Urgent or critical',
                    value: serious,
                    color: serious > 0 ? AppColors.alert : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _Section(
                title: 'By type',
                child: _CategoryBars(posts: posts),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'By severity',
                child: _SeverityBreakdown(posts: posts),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.color});
  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: textTheme.headlineMedium?.copyWith(
                color: color ?? AppColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: textTheme.bodySmall, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

/// Horizontal bars, longest first, each labelled with its count.
class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.posts});
  final List<CommunityPost> posts;

  @override
  Widget build(BuildContext context) {
    final counts = <PostCategory, int>{};
    for (final post in posts) {
      counts[post.category] = (counts[post.category] ?? 0) + 1;
    }
    final rows = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = rows.first.value;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        for (final row in rows)
          Semantics(
            label: '${row.key.label}: ${row.value}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Row(
                      children: [
                        Icon(
                          categoryIcon(row.key),
                          size: 16,
                          color: AppColors.mutedText,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            row.key.label,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 14,
                          width: (constraints.maxWidth * row.value / max).clamp(
                            6.0,
                            constraints.maxWidth,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${row.value}',
                      textAlign: TextAlign.right,
                      style: textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One stacked bar split by severity, with a labelled key underneath.
class _SeverityBreakdown extends StatelessWidget {
  const _SeverityBreakdown({required this.posts});
  final List<CommunityPost> posts;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in PostSeverity.values)
        s: posts.where((p) => p.severity == s).length,
    };
    final textTheme = Theme.of(context).textTheme;
    final present = PostSeverity.values.where((s) => counts[s]! > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < present.length; i++) ...[
                  if (i > 0) Container(width: 2, color: AppColors.card),
                  Expanded(
                    flex: counts[present[i]]!,
                    child: ColoredBox(color: severityColor(present[i])),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final s in PostSeverity.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: severityColor(s),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${s.label} ${counts[s]}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
