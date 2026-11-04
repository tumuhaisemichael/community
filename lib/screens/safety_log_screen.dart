import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import '../services/live_value.dart';
import '../theme/home_tone.dart';
import '../widgets/community_ui.dart';
import '../widgets/hero_header.dart';
import '../widgets/overlap_header.dart';
import '../widgets/post_card.dart';
import '../widgets/stat_widgets.dart';

enum _LogFilter { all, urgent, week }

/// Every incident the signed-in user has reported.
class SafetyLogScreen extends StatefulWidget {
  const SafetyLogScreen({
    super.key,
    required this.authService,
    required this.postRepository,
  });

  final AuthService authService;
  final PostRepository postRepository;

  @override
  State<SafetyLogScreen> createState() => _SafetyLogScreenState();
}

class _SafetyLogScreenState extends State<SafetyLogScreen> {
  // Opened once: switching filters must not reload the list.
  late final LiveValue<List<CommunityPost>> _posts = LiveValue(
    widget.postRepository.getPostsStream(),
  );
  _LogFilter _filter = _LogFilter.all;

  @override
  void dispose() {
    _posts.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.authService.currentUser?.uid ?? '';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: StreamBuilder<List<CommunityPost>>(
          stream: _posts.stream,
          initialData: _posts.latest,
          builder: (context, snapshot) {
            final mine = [
              for (final post in snapshot.data ?? const <CommunityPost>[])
                if (post.authorId == me) post,
            ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
            final urgent = mine.where((p) => p.severity.isSerious).length;
            final thisWeek = mine
                .where((p) => p.createdAt.isAfter(weekAgo))
                .length;
            final shown = switch (_filter) {
              _LogFilter.all => mine,
              _LogFilter.urgent => [
                for (final p in mine)
                  if (p.severity.isSerious) p,
              ],
              _LogFilter.week => [
                for (final p in mine)
                  if (p.createdAt.isAfter(weekAgo)) p,
              ],
            };

            return ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                OverlapHeader(
                  overlap: 28,
                  header: PageHeroHeader(
                    title: 'My Safety Log',
                    subtitle: snapshot.hasData
                        ? 'You have reported ${mine.length} '
                              'incident${mine.length == 1 ? '' : 's'}.'
                        : 'Incidents you have reported',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: StatCard(
                                  icon: Icons.edit_note_rounded,
                                  value: '${mine.length}',
                                  label: 'Total reports',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatCard(
                                  icon: Icons.date_range_rounded,
                                  value: '$thisWeek',
                                  label: 'This week',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StatCard(
                                  icon: Icons.warning_amber_rounded,
                                  value: '$urgent',
                                  label: 'Urgent',
                                  color: urgent > 0 ? HomeTone.red : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final (filter, label) in const [
                                (_LogFilter.all, 'All'),
                                (_LogFilter.urgent, 'Urgent'),
                                (_LogFilter.week, 'This week'),
                              ]) ...[
                                FilterPill(
                                  label: label,
                                  selected: _filter == filter,
                                  onTap: () => setState(() => _filter = filter),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (!snapshot.hasData)
                          for (var i = 0; i < 2; i++)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: SkeletonBox(
                                height: 150,
                                radius: 20,
                                color: HomeTone.skeleton,
                              ),
                            )
                        else if (shown.isEmpty)
                          InfoPanel(
                            icon: Icons.edit_note_rounded,
                            title: mine.isEmpty
                                ? 'No reports yet'
                                : 'Nothing here',
                            message: mine.isEmpty
                                ? 'Incidents you report appear here, so you '
                                      'can keep track of them.'
                                : 'No reports match this filter.',
                          )
                        else
                          for (final post in shown)
                            PostCard(
                              post: post,
                              authService: widget.authService,
                              postRepository: widget.postRepository,
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
