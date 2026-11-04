import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../models/community_post.dart';
import '../models/vacation_watch.dart';
import '../repositories/post_repository.dart';
import '../repositories/vacation_watch_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_tone.dart';
import '../widgets/hero_header.dart';
import '../widgets/post_card.dart';
import '../widgets/community_ui.dart';
import 'report_incident_screen.dart';
import 'vacation_watch_screen.dart';

class CommunityBulletinScreen extends StatefulWidget {
  const CommunityBulletinScreen({
    super.key,
    required this.authService,
    required this.postRepository,
    this.currentLocation,
    this.vacationWatchRepository,
  });

  final AuthService authService;
  final PostRepository postRepository;

  /// Defaults to the Firestore-backed repository. Tests pass their own.
  final VacationWatchRepository? vacationWatchRepository;

  /// Used to show how far away each report is.
  final LatLng? currentLocation;

  @override
  State<CommunityBulletinScreen> createState() =>
      _CommunityBulletinScreenState();
}

class _CommunityBulletinScreenState extends State<CommunityBulletinScreen> {
  // Created on first use, when the Vacation Watch tab opens.
  late final VacationWatchRepository _vacationWatchRepository =
      widget.vacationWatchRepository ?? VacationWatchRepository();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  String get _currentUserId => widget.authService.currentUser?.uid ?? '';

  String get _currentUserName {
    final user = widget.authService.currentUser;
    if (user?.displayName?.trim().isNotEmpty == true) {
      return user!.displayName!.trim();
    }
    if (user?.email?.trim().isNotEmpty == true) {
      return user!.email!.split('@').first;
    }
    return 'Member';
  }

  Future<void> _submitPost() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final user = widget.authService.currentUser;
      final post = CommunityPost(
        id: '',
        authorName: user?.displayName ?? user?.email ?? 'Member',
        authorId: user?.uid ?? '',
        content: text,
        createdAt: DateTime.now(),
        likes: 0,
        category: PostCategory.general,
      );

      await widget.postRepository.addPost(post);
      _contentController.clear();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _claimShift(VacationWatch watch, WatchShift shift) async {
    if (_currentUserId.isEmpty) {
      _showMessage('Sign in to claim vacation coverage days.');
      return;
    }

    try {
      await _vacationWatchRepository.claimShift(
        watch: watch,
        shiftId: shift.id,
        watcherId: _currentUserId,
        watcherName: _currentUserName,
      );
      _showMessage(
        'You claimed ${DateFormat('EEE, MMM d').format(shift.startsAt)} for ${watch.ownerName}.',
      );
    } catch (error) {
      _showMessage('Could not claim that day: $error');
    }
  }

  static _WatchPhase _phaseOf(VacationWatch watch) {
    final now = DateTime.now();
    final lastDay = DateTime(
      watch.endDate.year,
      watch.endDate.month,
      watch.endDate.day,
      23,
      59,
    );
    if (watch.status == VacationWatchStatus.completed ||
        lastDay.isBefore(now)) {
      return _WatchPhase.past;
    }
    if (watch.startDate.isAfter(now)) return _WatchPhase.upcoming;
    return _WatchPhase.active;
  }

  /// Active first, then upcoming (soonest first), then past (latest first).
  static int _byRelevance(VacationWatch a, VacationWatch b) {
    final pa = _phaseOf(a).index;
    final pb = _phaseOf(b).index;
    if (pa != pb) return pa.compareTo(pb);
    return _phaseOf(a) == _WatchPhase.past
        ? b.endDate.compareTo(a.endDate)
        : a.startDate.compareTo(b.startDate);
  }

  Future<void> _openVacationWatchPlanner() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VacationWatchScreen(authService: widget.authService),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _matchesFilter(CommunityPost post) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.urgent:
        return post.severity.isSerious;
      case _Filter.incidents:
        return post.category != PostCategory.general;
      case _Filter.announcements:
        return post.category == PostCategory.general;
    }
  }

  void _openFullReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportIncidentScreen(
          authService: widget.authService,
          postRepository: widget.postRepository,
          initialLocation: widget.currentLocation,
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: HomeTone.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeTone.border),
        boxShadow: HomeTone.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: HomeTone.actionGradient,
              ),
            ),
            child: Text(
              _currentUserName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _contentController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: HomeTone.ink, fontSize: 13.5),
              cursorColor: HomeTone.violet,
              decoration: const InputDecoration(
                hintText: 'Share an update, alert or announcement…',
                hintStyle: TextStyle(color: HomeTone.muted, fontSize: 13.5),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Full report with photos',
            onPressed: _openFullReport,
            icon: const Icon(
              Icons.add_photo_alternate_outlined,
              color: HomeTone.ink,
              size: 26,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Post',
            onPressed: _isSubmitting ? null : _submitPost,
            style: IconButton.styleFrom(
              backgroundColor: HomeTone.violet,
              disabledBackgroundColor: HomeTone.violet.withValues(alpha: .5),
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            icon: _isSubmitting
                ? const ButtonSpinner()
                : Transform.rotate(
                    angle: -0.5,
                    child: const Icon(Icons.send_rounded, size: 22),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _Filter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _Filter.values[index];
          final selected = filter == _filter;
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
                onTap: () => setState(() => _filter = filter),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: filter.icon == null ? 24 : 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (filter.icon != null) ...[
                        Icon(
                          filter.icon,
                          size: 20,
                          color: selected ? Colors.white : filter.iconColor,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        filter.label,
                        style: TextStyle(
                          color: selected ? Colors.white : HomeTone.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUpdatesTab() {
    return StreamBuilder<List<CommunityPost>>(
      stream: widget.postRepository.getPostsStream(),
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final posts = (snapshot.data ?? []).where(_matchesFilter).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildComposer(),
            const SizedBox(height: 14),
            _buildFilters(),
            const SizedBox(height: 14),
            if (loading)
              for (var i = 0; i < 3; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonBox(
                    height: 150,
                    radius: 20,
                    color: HomeTone.skeleton,
                  ),
                )
            else if (snapshot.hasError)
              const EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load updates',
                message: 'Check your connection and try again.',
              )
            else if (posts.isEmpty)
              EmptyState(
                icon: Icons.forum_outlined,
                title: _filter == _Filter.all
                    ? 'No updates yet'
                    : 'Nothing in ${_filter.label.toLowerCase()}',
                message: _filter == _Filter.all
                    ? 'Share the first announcement with your neighbours.'
                    : 'Try another filter.',
              )
            else
              for (final post in posts)
                PostCard(
                  post: post,
                  authService: widget.authService,
                  postRepository: widget.postRepository,
                  currentLocation: widget.currentLocation,
                ),
          ],
        );
      },
    );
  }

  _WatchFilter _watchFilter = _WatchFilter.all;

  /// Opens a neighbour's watch in a pull-up with the day-claiming controls.
  /// Reads the live stream so claims show up straight away.
  void _openWatch(String watchId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StreamBuilder<List<VacationWatch>>(
        stream: _vacationWatchRepository.watchAll(),
        builder: (context, snapshot) {
          final match = (snapshot.data ?? const <VacationWatch>[]).where(
            (w) => w.id == watchId,
          );
          if (match.isEmpty) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: _BulletinVacationCard(
                watch: match.first,
                currentUserId: _currentUserId,
                onClaimShift: (shift) => _claimShift(match.first, shift),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVacationTab() {
    return StreamBuilder<List<VacationWatch>>(
      stream: _vacationWatchRepository.watchAll(),
      builder: (context, snapshot) {
        final watches = (snapshot.data ?? const <VacationWatch>[])
            .where((w) => w.status != VacationWatchStatus.cancelled)
            .toList();
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        final mine = watches.where((w) => w.ownerId == _currentUserId).toList()
          ..sort(_byRelevance);
        final others =
            watches
                .where((w) => w.ownerId != _currentUserId)
                .where((w) => _watchFilter.matches(_phaseOf(w)))
                .toList()
              ..sort(_byRelevance);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _PlanHeroCard(onPlan: _openVacationWatchPlanner),
            const SizedBox(height: 18),
            _SectionTitle(
              'My Vacation Watch',
              action: TextButton(
                onPressed: _openVacationWatchPlanner,
                style: TextButton.styleFrom(foregroundColor: HomeTone.violet),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 17),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (loading)
              const SkeletonBox(
                height: 170,
                radius: 20,
                color: HomeTone.skeleton,
              )
            else if (snapshot.hasError)
              const _InfoCard(
                icon: Icons.wifi_off_rounded,
                message:
                    'Could not load vacation watches. Check your connection.',
              )
            else if (mine.isEmpty)
              _InfoCard(
                icon: Icons.luggage_outlined,
                message: 'You have no vacation watch planned.',
                action: TextButton(
                  onPressed: _openVacationWatchPlanner,
                  style: TextButton.styleFrom(foregroundColor: HomeTone.violet),
                  child: const Text('Plan one'),
                ),
              )
            else
              _MyWatchCard(
                watch: mine.first,
                activity: _vacationWatchRepository.watchActivity(mine.first.id),
                onTap: _openVacationWatchPlanner,
              ),
            const SizedBox(height: 20),
            const _SectionTitle('Neighbourhood Watches'),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in _WatchFilter.values) ...[
                    _SmallChip(
                      label: filter.label,
                      selected: filter == _watchFilter,
                      onTap: () => setState(() => _watchFilter = filter),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              for (var i = 0; i < 2; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonBox(
                    height: 90,
                    radius: 18,
                    color: HomeTone.skeleton,
                  ),
                )
            else if (others.isEmpty)
              _InfoCard(
                icon: Icons.cottage_outlined,
                message: _watchFilter == _WatchFilter.all
                    ? 'No one is away right now. When a neighbour plans a '
                          'trip, it appears here.'
                    : 'No ${_watchFilter.label.toLowerCase()} watches.',
              )
            else
              for (final watch in others)
                _NeighbourWatchCard(
                  watch: watch,
                  phase: _phaseOf(watch),
                  onTap: () => _openWatch(watch.id),
                ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: HomeTone.canvas,
          body: Column(
            children: [
              const PageHeroHeader(
                title: 'Community Bulletin',
                subtitle:
                    'Updates, incidents and announcements\n'
                    'from your neighbourhood.',
                badge: _MegaphoneBadge(),
                bottom: _BulletinTabs(),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildUpdatesTab(),
                    // Built only when the tab is shown.
                    Builder(builder: (_) => _buildVacationTab()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletinTabs extends StatelessWidget {
  const _BulletinTabs();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: TabBar(
        labelColor: HomeTone.violet,
        unselectedLabelColor: HomeTone.ink,
        indicatorColor: HomeTone.violet,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: HomeTone.border,
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            height: 46,
            child: _TabLabel(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Updates',
            ),
          ),
          Tab(
            height: 46,
            child: _TabLabel(
              icon: Icons.home_outlined,
              label: 'Vacation Watch',
            ),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    ],
  );
}

/// White megaphone with sound lines, shown in the header.
class _MegaphoneBadge extends StatelessWidget {
  const _MegaphoneBadge();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.rotate(
      angle: -0.25,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .18),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.campaign_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    ),
  );
}

class _BulletinVacationCard extends StatelessWidget {
  const _BulletinVacationCard({
    required this.watch,
    required this.currentUserId,
    required this.onClaimShift,
  });

  final VacationWatch watch;
  final String currentUserId;
  final void Function(WatchShift shift) onClaimShift;

  Future<void> _showShiftDetails(BuildContext context, WatchShift shift) {
    final claimedAt = shift.claimedAt;
    final endsAt = shift.endsAt;

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEE, MMM d').format(shift.startsAt),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _ShiftInfoRow(
                label: 'Claimed by',
                value: shift.watcherName ?? 'Unassigned',
              ),
              _ShiftInfoRow(label: 'Status', value: shift.status.label),
              _ShiftInfoRow(
                label: 'Coverage',
                value: endsAt == null
                    ? DateFormat('HH:mm').format(shift.startsAt)
                    : '${DateFormat('HH:mm').format(shift.startsAt)} - ${DateFormat('HH:mm').format(endsAt)}',
              ),
              if (claimedAt != null)
                _ShiftInfoRow(
                  label: 'Claimed on',
                  value: DateFormat('MMM d, HH:mm').format(claimedAt),
                ),
              if (shift.completedAt != null)
                _ShiftInfoRow(
                  label: 'Completed on',
                  value: DateFormat('MMM d, HH:mm').format(shift.completedAt!),
                ),
              const SizedBox(height: 10),
              Text(
                'This day covers ${watch.address}. Tasks for the trip stay visible on the main bulletin card.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasOpenShifts = watch.shifts.any((shift) => shift.isOpen);
    final isClosed =
        watch.status == VacationWatchStatus.cancelled ||
        (watch.status == VacationWatchStatus.completed && !hasOpenShifts);
    final openShifts = watch.shifts.where((shift) => shift.isOpen).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final claimableShifts = isClosed ? const <WatchShift>[] : openShifts;
    final claimedShifts =
        watch.shifts
            .where((shift) => shift.status != WatchShiftStatus.open)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final myShifts =
        watch.shifts
            .where((shift) => shift.isAssignedTo(currentUserId))
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        watch.ownerName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('MMM d').format(watch.startDate)} - ${DateFormat('MMM d').format(watch.endDate)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: '${watch.karmaReward} karma/day',
                  color: AppColors.amber,
                  icon: Icons.star_rounded,
                ),
              ],
            ),
            const SizedBox(height: 8),
            StatusPill(
              label: isClosed
                  ? watch.status.label
                  : (watch.status == VacationWatchStatus.completed
                        ? 'Reopened'
                        : watch.status.label),
              color: isClosed
                  ? AppColors.safe
                  : watch.status == VacationWatchStatus.alert
                  ? AppColors.alert
                  : AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(watch.address, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: watch.tasks
                  .map(
                    (task) => Chip(
                      label: Text(task.title),
                      backgroundColor: task.isCritical
                          ? AppColors.alertDim
                          : AppColors.watchDim,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            Text('Open days', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            if (isClosed)
              const Text('This vacation watch has already been closed.')
            else if (claimableShifts.isEmpty)
              const Text('All days have already been claimed.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: claimableShifts
                    .map(
                      (shift) => ActionChip(
                        avatar: const Icon(
                          Icons.event_available_outlined,
                          size: 18,
                        ),
                        label: Text(
                          DateFormat('EEE, MMM d').format(shift.startsAt),
                        ),
                        onPressed: currentUserId == watch.ownerId
                            ? null
                            : () => onClaimShift(shift),
                      ),
                    )
                    .toList(),
              ),
            if (claimedShifts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Claimed days',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: claimedShifts
                    .map(
                      (shift) => ActionChip(
                        avatar: Icon(
                          shift.status == WatchShiftStatus.completed
                              ? Icons.check_circle_outline
                              : Icons.person_outline,
                          size: 18,
                        ),
                        label: Text(
                          DateFormat('EEE, MMM d').format(shift.startsAt),
                        ),
                        backgroundColor:
                            shift.status == WatchShiftStatus.completed
                            ? AppColors.safeDim
                            : AppColors.canvas,
                        onPressed: () => _showShiftDetails(context, shift),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (myShifts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Your claimed days here',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: myShifts
                    .map(
                      (shift) => ActionChip(
                        label: Text(
                          DateFormat('EEE, MMM d').format(shift.startsAt),
                        ),
                        backgroundColor: AppColors.safeDim,
                        onPressed: () => _showShiftDetails(context, shift),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShiftInfoRow extends StatelessWidget {
  const _ShiftInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Filter {
  all('All', null, null),
  urgent('Urgent', Icons.warning_rounded, HomeTone.red),
  incidents('Incidents', Icons.directions_car_rounded, HomeTone.violet),
  announcements('Announcements', Icons.campaign_rounded, HomeTone.violet);

  const _Filter(this.label, this.icon, this.iconColor);
  final String label;
  final IconData? icon;
  final Color? iconColor;
}

// ------------------------------------------------------- vacation watch tab

/// Ordered so sorting by index puts active first, then upcoming, then past.
enum _WatchPhase { active, upcoming, past }

enum _WatchFilter {
  all('All'),
  upcoming('Upcoming'),
  active('Active'),
  past('Past');

  const _WatchFilter(this.label);
  final String label;

  bool matches(_WatchPhase phase) => switch (this) {
    _WatchFilter.all => true,
    _WatchFilter.upcoming => phase == _WatchPhase.upcoming,
    _WatchFilter.active => phase == _WatchPhase.active,
    _WatchFilter.past => phase == _WatchPhase.past,
  };
}

final DateFormat _shortDate = DateFormat('MMM d');

String _dateRange(VacationWatch watch) =>
    '${_shortDate.format(watch.startDate)} – ${_shortDate.format(watch.endDate)}';

/// Last part of the address, e.g. "Kampala" from "Plot 4, Kira Rd, Kampala".
String _area(String address) {
  final parts = address
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);
  return parts.isEmpty ? '' : parts.last;
}

String _firstName(String name) {
  final first = name.trim().split(RegExp(r'\s+')).first;
  return first.isEmpty ? 'Neighbour' : first;
}

class _PlanHeroCard extends StatelessWidget {
  const _PlanHeroCard({required this.onPlan});
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F2FF), Color(0xFFE6DCFF)],
        ),
        boxShadow: HomeTone.cardShadow,
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -6,
            bottom: 0,
            child: ExcludeSemantics(child: _HouseIllustration()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 104, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Keep your home safe while you’re away',
                  style: TextStyle(
                    color: HomeTone.ink,
                    fontSize: 16.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Let trusted neighbours keep an eye on your home and '
                  'report anything unusual.',
                  style: TextStyle(
                    color: HomeTone.muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onPlan,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeTone.violet,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Plan a Vacation Watch'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// House with a shield, drawn from icons, for the hero card.
class _HouseIllustration extends StatelessWidget {
  const _HouseIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 110,
    height: 118,
    child: Stack(
      children: [
        Positioned(
          right: 4,
          bottom: 6,
          child: Icon(
            Icons.park_rounded,
            size: 48,
            color: HomeTone.violet.withValues(alpha: .25),
          ),
        ),
        Positioned(
          right: 12,
          bottom: -6,
          child: Icon(
            Icons.home_rounded,
            size: 86,
            color: HomeTone.violet.withValues(alpha: .55),
          ),
        ),
        Positioned(
          left: 4,
          top: 8,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: HomeTone.cardShadow,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: HomeTone.violet,
              size: 22,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: const TextStyle(
              color: HomeTone.ink,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      ?action,
    ],
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HomeTone.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: HomeTone.muted, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: HomeTone.muted, fontSize: 13),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? HomeTone.violet : HomeTone.violetDim,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : HomeTone.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

/// "Active" / "Upcoming" / "Completed" (or "Alert", "Arriving home").
class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.watch, required this.phase});
  final VacationWatch watch;
  final _WatchPhase phase;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, tint) = switch (phase) {
      _WatchPhase.past => (
        'Completed',
        Icons.check_circle_rounded,
        HomeTone.muted,
        const Color(0xFFEFEDF5),
      ),
      _WatchPhase.upcoming => (
        'Upcoming',
        Icons.calendar_month_rounded,
        HomeTone.violet,
        HomeTone.violetDim,
      ),
      _WatchPhase.active => switch (watch.status) {
        VacationWatchStatus.alert => (
          'Alert',
          Icons.warning_rounded,
          HomeTone.red,
          HomeTone.redDim,
        ),
        VacationWatchStatus.arrivingHome => (
          'Arriving home',
          Icons.directions_walk_rounded,
          HomeTone.blue,
          HomeTone.blueDim,
        ),
        _ => (
          'Active',
          Icons.check_circle_rounded,
          HomeTone.green,
          HomeTone.greenDim,
        ),
      },
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: HomeTone.muted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: HomeTone.muted, fontSize: 12.5),
        ),
      ),
    ],
  );
}

class _MyWatchCard extends StatelessWidget {
  const _MyWatchCard({
    required this.watch,
    required this.activity,
    required this.onTap,
  });

  final VacationWatch watch;
  final Stream<List<WatchActivity>> activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = watch.endDate.difference(watch.startDate).inDays + 1;
    final watchers = {
      for (final shift in watch.shifts)
        if (shift.watcherId != null) shift.watcherId!,
      ...watch.watcherIds,
    }.length;

    return Material(
      color: HomeTone.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HomeTone.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: HomeTone.violetDim,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.luggage_rounded,
                      color: HomeTone.violet,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          watch.address.trim().isEmpty
                              ? 'Home Away'
                              : watch.address.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HomeTone.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _IconText(
                          Icons.calendar_today_outlined,
                          '${_dateRange(watch)} ($days day${days == 1 ? '' : 's'})',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PhasePill(
                    watch: watch,
                    phase: _CommunityBulletinScreenState._phaseOf(watch),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: HomeTone.muted,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<WatchActivity>>(
                stream: activity,
                builder: (context, snapshot) {
                  final updates = snapshot.data?.length;
                  return Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          icon: Icons.visibility_outlined,
                          value: '$watchers',
                          label: 'Neighbours watching',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          icon: Icons.notifications_none_rounded,
                          value: updates == null ? '–' : '$updates',
                          label: 'Watch updates',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Stat(
                          icon: Icons.star_outline_rounded,
                          iconColor: const Color(0xFFE6A700),
                          value: '${watch.karmaReward}',
                          label: 'karma/day',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = HomeTone.violet,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F3FD),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: HomeTone.ink,
                  fontSize: 15,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomeTone.muted,
                  fontSize: 10.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NeighbourWatchCard extends StatelessWidget {
  const _NeighbourWatchCard({
    required this.watch,
    required this.phase,
    required this.onTap,
  });

  final VacationWatch watch;
  final _WatchPhase phase;
  final VoidCallback onTap;

  static IconData _taskIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('trash') || t.contains('bin')) {
      return Icons.delete_outline_rounded;
    }
    if (t.contains('mail') || t.contains('post')) return Icons.mail_outline;
    if (t.contains('package') || t.contains('parcel')) {
      return Icons.inventory_2_outlined;
    }
    if (t.contains('plant') || t.contains('water')) {
      return Icons.water_drop_outlined;
    }
    if (t.contains('light')) return Icons.lightbulb_outline_rounded;
    if (t.contains('pet') || t.contains('dog') || t.contains('cat')) {
      return Icons.pets_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final area = _area(watch.address);
    final name = _firstName(watch.ownerName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HomeTone.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: HomeTone.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: HomeTone.violetDim,
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      color: HomeTone.violet,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$name’s Home',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HomeTone.ink,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PhasePill(watch: watch, phase: phase),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          _IconText(
                            Icons.calendar_today_outlined,
                            _dateRange(watch),
                          ),
                          if (area.isNotEmpty)
                            _IconText(Icons.location_on_outlined, area),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _KarmaPill(watch: watch, phase: phase),
                      if (watch.tasks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final task in watch.tasks.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: task.isCritical
                                      ? HomeTone.redDim
                                      : const Color(0xFFF3F0FB),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _taskIcon(task.title),
                                      size: 14,
                                      color: task.isCritical
                                          ? HomeTone.red
                                          : HomeTone.ink,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      task.title,
                                      style: const TextStyle(
                                        color: HomeTone.ink,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (watch.tasks.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+${watch.tasks.length - 3} more',
                                  style: const TextStyle(
                                    color: HomeTone.muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: HomeTone.muted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "⭐ 10 karma/day · 3 days open" on a neighbour's watch card.
class _KarmaPill extends StatelessWidget {
  const _KarmaPill({required this.watch, required this.phase});
  final VacationWatch watch;
  final _WatchPhase phase;

  static const Color _gold = Color(0xFFB7791F);

  @override
  Widget build(BuildContext context) {
    final open = phase == _WatchPhase.past ? 0 : watch.openShiftCount;
    final text = [
      '${watch.karmaReward} karma/day',
      if (open > 0) '$open day${open == 1 ? '' : 's'} open',
    ].join('  ·  ');
    return Semantics(
      label: open > 0
          ? 'Earn ${watch.karmaReward} karma for each day you watch. '
                '$open day${open == 1 ? '' : 's'} still open.'
          : 'Reward: ${watch.karmaReward} karma per day.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E0),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 15, color: Color(0xFFE6A700)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _gold,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
