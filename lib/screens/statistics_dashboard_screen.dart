import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../services/live_value.dart';
import '../theme/home_tone.dart';
import '../widgets/community_ui.dart';
import '../widgets/hero_header.dart';
import '../widgets/overlap_header.dart';
import '../widgets/stat_widgets.dart';

enum _Range { week, month, all }

/// Community incident numbers: totals, a 7-day trend, types and severity.
/// General updates (announcements) are not counted.
class StatisticsDashboardScreen extends StatefulWidget {
  const StatisticsDashboardScreen({super.key, required this.postRepository});
  final PostRepository postRepository;

  @override
  State<StatisticsDashboardScreen> createState() =>
      _StatisticsDashboardScreenState();
}

class _StatisticsDashboardScreenState extends State<StatisticsDashboardScreen> {
  // Opened once: switching the time range must not reload the data.
  late final LiveValue<List<CommunityPost>> _posts = LiveValue(
    widget.postRepository.getPostsStream(),
  );
  _Range _range = _Range.month;

  @override
  void dispose() {
    _posts.close();
    super.dispose();
  }

  static bool _isIncident(CommunityPost p) =>
      p.categories.any((c) => c != PostCategory.general);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: StreamBuilder<List<CommunityPost>>(
          stream: _posts.stream,
          initialData: _posts.latest,
          builder: (context, snapshot) {
            final incidents = [
              for (final p in snapshot.data ?? const <CommunityPost>[])
                if (_isIncident(p)) p,
            ];
            final now = DateTime.now();
            final since = switch (_range) {
              _Range.week => now.subtract(const Duration(days: 7)),
              _Range.month => now.subtract(const Duration(days: 30)),
              _Range.all => null,
            };
            final inRange = [
              for (final p in incidents)
                if (since == null || p.createdAt.isAfter(since)) p,
            ];
            final serious = inRange.where((p) => p.severity.isSerious).length;
            final counts = <PostCategory, int>{};
            for (final post in inRange) {
              for (final c in post.categories) {
                if (c == PostCategory.general) continue;
                counts[c] = (counts[c] ?? 0) + 1;
              }
            }
            final byType = counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                OverlapHeader(
                  overlap: 28,
                  header: const PageHeroHeader(
                    title: 'Crime Stats',
                    subtitle:
                        'Incidents reported by the community. General updates '
                        'are not counted.',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RangeSwitch(
                          value: _range,
                          onChanged: (r) => setState(() => _range = r),
                        ),
                        const SizedBox(height: 12),
                        if (!snapshot.hasData) ...[
                          const SkeletonBox(
                            height: 110,
                            radius: 18,
                            color: HomeTone.skeleton,
                          ),
                          const SizedBox(height: 12),
                          const SkeletonBox(
                            height: 220,
                            radius: 20,
                            color: HomeTone.skeleton,
                          ),
                        ] else if (incidents.isEmpty)
                          const InfoPanel(
                            icon: Icons.bar_chart_rounded,
                            title: 'No incidents yet',
                            message:
                                'Stats appear once neighbours start reporting.',
                          )
                        else ...[
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: StatCard(
                                    icon: Icons.report_outlined,
                                    value: '${inRange.length}',
                                    label: 'Incidents',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: StatCard(
                                    icon: Icons.warning_amber_rounded,
                                    value: '$serious',
                                    label: 'Urgent or critical',
                                    color: serious > 0 ? HomeTone.red : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: StatCard(
                                    icon: byType.isEmpty
                                        ? Icons.category_outlined
                                        : categoryIcon(byType.first.key),
                                    value: byType.isEmpty
                                        ? '–'
                                        : byType.first.key.label,
                                    label: 'Most common',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Panel(
                            title: 'Last 7 days',
                            subtitle: 'Incidents reported each day',
                            child: _DailyBars(incidents: incidents),
                          ),
                          const SizedBox(height: 12),
                          _Panel(
                            title: 'By type',
                            subtitle:
                                'A report with several types counts '
                                'once for each.',
                            child: byType.isEmpty
                                ? const _Muted('No incidents in this period.')
                                : _TypeBars(rows: byType),
                          ),
                          const SizedBox(height: 12),
                          _Panel(
                            title: 'By severity',
                            child: inRange.isEmpty
                                ? const _Muted('No incidents in this period.')
                                : _SeverityBreakdown(posts: inRange),
                          ),
                        ],
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

class _RangeSwitch extends StatelessWidget {
  const _RangeSwitch({required this.value, required this.onChanged});
  final _Range value;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: HomeTone.border),
      boxShadow: HomeTone.cardShadow,
    ),
    child: Row(
      children: [
        for (final (range, label) in const [
          (_Range.week, '7 days'),
          (_Range.month, '30 days'),
          (_Range.all, 'All time'),
        ])
          Expanded(
            child: Semantics(
              button: true,
              selected: value == range,
              child: GestureDetector(
                onTap: () => onChanged(range),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == range
                        ? HomeTone.violet
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: value == range ? Colors.white : HomeTone.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HomeTone.border),
      boxShadow: HomeTone.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: HomeTone.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(color: HomeTone.muted, fontSize: 12.5),
          ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: HomeTone.muted));
}

/// One column per day for the last 7 days, today on the right.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.incidents});
  final List<CommunityPost> incidents;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final counts = [
      for (final day in days)
        incidents.where((p) => DateUtils.isSameDay(p.createdAt, day)).length,
    ];
    final max = counts.fold<int>(0, (a, b) => a > b ? a : b);
    const chartHeight = 110.0;

    return Semantics(
      container: true,
      label: [
        for (var i = 0; i < days.length; i++)
          '${DateFormat('EEEE').format(days[i])} ${counts[i]}',
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${counts[i]}',
                    style: TextStyle(
                      color: counts[i] == 0 ? HomeTone.muted : HomeTone.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: max == 0
                        ? 4
                        : (chartHeight * counts[i] / max).clamp(4, chartHeight),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      gradient: counts[i] == 0
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: HomeTone.actionGradient,
                            ),
                      color: counts[i] == 0 ? HomeTone.border : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i == days.length - 1
                        ? 'Today'
                        : DateFormat('EEE').format(days[i]),
                    style: TextStyle(
                      color: i == days.length - 1
                          ? HomeTone.violet
                          : HomeTone.muted,
                      fontSize: 11.5,
                      fontWeight: i == days.length - 1
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal bars, longest first, each with its icon and count.
class _TypeBars extends StatelessWidget {
  const _TypeBars({required this.rows});
  final List<MapEntry<PostCategory, int>> rows;

  @override
  Widget build(BuildContext context) {
    final max = rows.first.value;
    return Column(
      children: [
        for (final row in rows)
          Semantics(
            container: true,
            label: '${row.key.label}: ${row.value}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: HomeTone.violetDim,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      categoryIcon(row.key),
                      size: 17,
                      color: HomeTone.violet,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.key.label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: HomeTone.ink,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${row.value}',
                              style: const TextStyle(
                                color: HomeTone.ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: row.value / max,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFF1EDFA),
                            valueColor: const AlwaysStoppedAnimation(
                              HomeTone.violet,
                            ),
                          ),
                        ),
                      ],
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

/// One bar split by severity, with a key underneath.
class _SeverityBreakdown extends StatelessWidget {
  const _SeverityBreakdown({required this.posts});
  final List<CommunityPost> posts;

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in PostSeverity.values)
        s: posts.where((p) => p.severity == s).length,
    };
    final present = PostSeverity.values.where((s) => counts[s]! > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < present.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: counts[present[i]]!,
                    child: ColoredBox(color: HomeTone.severity(present[i])),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in PostSeverity.values)
              Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                decoration: BoxDecoration(
                  color: HomeTone.severity(s).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: HomeTone.severity(s),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${s.label}  ${counts[s]}',
                      style: const TextStyle(
                        color: HomeTone.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
