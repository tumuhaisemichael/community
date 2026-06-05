import 'package:flutter/material.dart';
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
                Text('Incident Distribution', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: stats.entries.map((e) {
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          title: '${e.key.name}\n${e.value}',
                          radius: 50,
                          color: _getCategoryColor(e.key),
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Total Reports: ${posts.length}', style: Theme.of(context).textTheme.titleMedium),
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
      case PostCategory.theft: return Colors.red;
      case PostCategory.fire: return Colors.orange;
      case PostCategory.medical: return Colors.blue;
      case PostCategory.assault: return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildLegend() {
    return Column(
      children: PostCategory.values.where((c) => c != PostCategory.general).map((c) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 12, height: 12, color: _getCategoryColor(c)),
              const SizedBox(width: 8),
              Text(c.name.toUpperCase()),
            ],
          ),
        );
      }).toList(),
    );
  }
}
