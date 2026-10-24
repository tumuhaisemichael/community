import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/community_post.dart';
import '../repositories/post_repository.dart';

class StatisticsDashboardScreen extends StatelessWidget {
  const StatisticsDashboardScreen({super.key, required this.postRepository});
  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crime Statistics')),
      body: StreamBuilder<List<CommunityPost>>(
        stream: postRepository.getPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data ?? [];
          final stats = _calculateStats(posts);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageIntro(
                  title: 'A clearer picture.',
                  subtitle: 'Understand the reports shared in your community.',
                  eyebrow: 'Crime Statistics',
                  icon: Icons.insights_rounded,
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incident Distribution',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        if (stats.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text('No incidents to display yet.'),
                            ),
                          )
                        else
                          SizedBox(
                            height: 230,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${stats.values.fold<int>(0, (total, count) => total + count)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                    ),
                                    const Text(
                                      'incidents',
                                      style: TextStyle(
                                        color: AppColors.mutedText,
                                      ),
                                    ),
                                  ],
                                ),
                                PieChart(
                                  PieChartData(
                                    centerSpaceRadius: 65,
                                    sectionsSpace: 4,
                                    sections: stats.entries
                                        .map(
                                          (e) => PieChartSectionData(
                                            value: e.value.toDouble(),
                                            title: '${e.value}',
                                            radius: 32,
                                            color: _getCategoryColor(e.key),
                                            titleStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Total Reports: ${posts.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _buildLegend(),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<PostCategory, int> _calculateStats(List<CommunityPost> posts) {
    final Map<PostCategory, int> stats = {};
    for (final post in posts) {
      if (post.category == PostCategory.general) continue;
      stats[post.category] = (stats[post.category] ?? 0) + 1;
    }
    return stats;
  }

  Color _getCategoryColor(PostCategory category) {
    switch (category) {
      case PostCategory.theft:
        return AppColors.alert;
      case PostCategory.fire:
        return AppColors.amber;
      case PostCategory.medical:
        return AppColors.watch;
      case PostCategory.assault:
        return const Color(0xFF77739C);
      default:
        return AppColors.mutedText;
    }
  }

  Widget _buildLegend() {
    return Column(
      children: PostCategory.values.where((c) => c != PostCategory.general).map(
        (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(c),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(c.name.toUpperCase()),
              ],
            ),
          );
        },
      ).toList(),
    );
  }
}
