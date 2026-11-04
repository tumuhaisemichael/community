import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/vacation_watch.dart';
import '../repositories/vacation_watch_repository.dart';
import '../services/auth_service.dart';
import '../services/live_value.dart';
import '../theme/home_tone.dart';
import '../widgets/community_ui.dart';
import '../widgets/hero_header.dart';
import '../widgets/overlap_header.dart';
import '../widgets/trip_widgets.dart';

/// The owner's view of their trips: karma earned, coverage numbers, tasks,
/// the day-by-day roster and what neighbours have reported.
class VacationWatchDashboardScreen extends StatefulWidget {
  const VacationWatchDashboardScreen({
    super.key,
    required this.authService,
    required this.repository,
    this.karmaPoints,
  });

  final AuthService authService;
  final VacationWatchRepository repository;

  /// The signed-in user's karma total; defaults to their Firestore record.
  final Stream<int>? karmaPoints;

  @override
  State<VacationWatchDashboardScreen> createState() =>
      _VacationWatchDashboardScreenState();
}

class _VacationWatchDashboardScreenState
    extends State<VacationWatchDashboardScreen> {
  String get _userId => widget.authService.currentUser?.uid ?? '';

  // Opened once and shared, so switching trips never flashes a loading state.
  late final LiveValue<int> _karma = LiveValue(
    widget.karmaPoints ??
        FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .snapshots()
            .map((doc) => (doc.data()?['karmaPoints'] as num?)?.toInt() ?? 0),
  );
  late final LiveValue<List<VacationWatch>> _trips = LiveValue(
    widget.repository.watchOwnedBy(_userId),
  );
  final Map<String, LiveValue<List<WatchActivity>>> _activity = {};

  String? _selectedId;
  bool _showAllActivity = false;

  Stream<List<WatchActivity>> _activityFor(String id) => _activity
      .putIfAbsent(id, () => LiveValue(widget.repository.watchActivity(id)))
      .stream;

  @override
  void dispose() {
    for (final live in [_karma, _trips, ..._activity.values]) {
      live.close();
    }
    super.dispose();
  }

  /// Active trips first, then upcoming, then the most recent past ones.
  static int _byRelevance(VacationWatch a, VacationWatch b) {
    int rank(VacationWatch w) {
      if (w.status == VacationWatchStatus.cancelled) return 3;
      final now = DateTime.now();
      if (w.status == VacationWatchStatus.completed ||
          w.endDate.isBefore(DateTime(now.year, now.month, now.day))) {
        return 2;
      }
      return w.startDate.isAfter(now) ? 1 : 0;
    }

    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return rank(a) >= 2
        ? b.endDate.compareTo(a.endDate)
        : a.startDate.compareTo(b.startDate);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: _userId.isEmpty
            ? Column(
                children: [
                  const PageHeroHeader(
                    title: 'Trip Dashboard',
                    subtitle: 'How your trips are being covered',
                    overlap: 0,
                  ),
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Sign in to see your trips',
                    ),
                  ),
                ],
              )
            : StreamBuilder<int>(
                stream: _karma.stream,
                initialData: _karma.latest,
                builder: (context, karmaSnap) =>
                    StreamBuilder<List<VacationWatch>>(
                      stream: _trips.stream,
                      initialData: _trips.latest,
                      builder: (context, snapshot) =>
                          _buildBody(karmaSnap.data ?? 0, snapshot),
                    ),
              ),
      ),
    );
  }

  Widget _buildBody(int karma, AsyncSnapshot<List<VacationWatch>> snapshot) {
    final trips = [...?snapshot.data]..sort(_byRelevance);
    final selected = trips.isEmpty
        ? null
        : trips.firstWhere(
            (t) => t.id == _selectedId,
            orElse: () => trips.first,
          );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        OverlapHeader(
          overlap: 40,
          header: const PageHeroHeader(
            title: 'Trip Dashboard',
            subtitle: 'How your trips are being covered',
            overlap: 40,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _KarmaCard(points: karma),
                const SizedBox(height: 14),
                if (snapshot.hasError)
                  const _Notice(
                    icon: Icons.wifi_off_rounded,
                    text: 'Could not load your trips. Check your connection.',
                  )
                else if (!snapshot.hasData)
                  const SkeletonBox(
                    height: 160,
                    radius: 20,
                    color: HomeTone.skeleton,
                  )
                else if (selected == null)
                  const _Notice(
                    icon: Icons.cottage_outlined,
                    text:
                        'No trips planned yet. Plan one from Vacation Watch '
                        'and it will appear here.',
                  )
                else ...[
                  if (trips.length > 1) ...[
                    _TripPicker(
                      trips: trips,
                      selectedId: selected.id,
                      onSelect: (id) => setState(() {
                        _selectedId = id;
                        _showAllActivity = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _TripSummary(watch: selected),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'Tasks',
                    action: selected.tasks.isEmpty
                        ? null
                        : _LinkButton(
                            label: 'Task details',
                            onTap: () =>
                                showTaskDetailsSheet(context, selected),
                          ),
                    child: selected.tasks.isEmpty
                        ? const _Muted('No tasks were set for this trip.')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final task in selected.tasks)
                                TaskChip(task: task),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: 'Roster Timeline',
                    child: selected.shifts.isEmpty
                        ? const _Muted('No days to cover.')
                        : RosterTimeline(
                            shifts: [
                              ...selected.shifts,
                            ]..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
                          ),
                  ),
                  const SizedBox(height: 14),
                  StreamBuilder<List<WatchActivity>>(
                    stream: _activityFor(selected.id),
                    initialData: _activity[selected.id]?.latest,
                    builder: (context, snap) {
                      final items = [...?snap.data]
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      final shown = _showAllActivity
                          ? items
                          : items.take(3).toList();
                      return _Panel(
                        title: 'Activity Feed',
                        action: items.length > 3
                            ? _LinkButton(
                                label: _showAllActivity
                                    ? 'Show less'
                                    : 'See all (${items.length})',
                                onTap: () => setState(
                                  () => _showAllActivity = !_showAllActivity,
                                ),
                              )
                            : null,
                        child: items.isEmpty
                            ? const _Muted('No updates logged yet.')
                            : Column(
                                children: [
                                  for (final item in shown)
                                    ActivityTile(item: item),
                                ],
                              ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ widgets

class _KarmaCard extends StatelessWidget {
  const _KarmaCard({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .25)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF4C1D95).withValues(alpha: .3),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: 6,
          bottom: -12,
          child: ExcludeSemantics(
            child: Icon(
              Icons.home_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: .18),
            ),
          ),
        ),
        Positioned(
          right: 74,
          top: 14,
          child: ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: HomeTone.violet,
                size: 24,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 120, 18),
          child: Semantics(
            label: '$points karma earned',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Karma Earned',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFBBF24),
                      size: 32,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$points',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Earn karma for each day you cover and keep your '
                  'neighbourhood safer together.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .85),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _TripPicker extends StatelessWidget {
  const _TripPicker({
    required this.trips,
    required this.selectedId,
    required this.onSelect,
  });
  final List<VacationWatch> trips;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: trips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (context, i) {
        final trip = trips[i];
        final selected = trip.id == selectedId;
        return Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? HomeTone.violet : HomeTone.card,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? HomeTone.violet : HomeTone.border,
              ),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onSelect(trip.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    '${DateFormat('MMM d').format(trip.startDate)} · '
                    '${trip.address.split(',').first.trim()}',
                    style: TextStyle(
                      color: selected ? Colors.white : HomeTone.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.watch});
  final VacationWatch watch;

  @override
  Widget build(BuildContext context) {
    final (label, color, tint) = tripStatus(watch);
    return _Surface(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HomeTone.violetDim,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  color: HomeTone.violet,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      watch.address.trim().isEmpty
                          ? 'My home'
                          : watch.address.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeTone.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 14,
                          color: HomeTone.violet,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tripDateRange(watch),
                            style: const TextStyle(
                              color: HomeTone.ink,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TripMetric(
                  icon: Icons.visibility_outlined,
                  value: watch.openShiftCount,
                  label: 'Open',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TripMetric(
                  icon: Icons.flag_outlined,
                  value: watch.claimedShiftCount,
                  label: 'Claimed',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TripMetric(
                  icon: Icons.check_circle_outline_rounded,
                  value: watch.completedShiftCount,
                  label: 'Completed',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, required this.padding});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HomeTone.border),
      boxShadow: HomeTone.cardShadow,
    ),
    child: child,
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: Semantics(
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
              ),
              ?action,
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(padding: const EdgeInsets.only(right: 6), child: child),
      ],
    ),
  );
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: HomeTone.violet,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 36),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const Icon(Icons.chevron_right_rounded, size: 20),
      ],
    ),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: HomeTone.muted, fontSize: 13));
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(icon, color: HomeTone.muted),
        const SizedBox(width: 12),
        Expanded(child: _Muted(text)),
      ],
    ),
  );
}
