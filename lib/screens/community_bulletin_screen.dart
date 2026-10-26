import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/community_post.dart';
import '../models/vacation_watch.dart';
import '../repositories/post_repository.dart';
import '../repositories/vacation_watch_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
import '../widgets/community_ui.dart';
import 'vacation_watch_screen.dart';

class CommunityBulletinScreen extends StatefulWidget {
  const CommunityBulletinScreen({
    super.key,
    required this.authService,
    required this.postRepository,
  });

  final AuthService authService;
  final PostRepository postRepository;

  @override
  State<CommunityBulletinScreen> createState() =>
      _CommunityBulletinScreenState();
}

class _CommunityBulletinScreenState extends State<CommunityBulletinScreen> {
  final VacationWatchRepository _vacationWatchRepository =
      VacationWatchRepository();
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

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.watchDim,
            child: Text(
              _currentUserName[0].toUpperCase(),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _contentController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Share an announcement',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          IconButton.filled(
            tooltip: 'Post',
            onPressed: _isSubmitting ? null : _submitPost,
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              for (var i = 0; i < 3; i++)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SkeletonBox(height: 150, radius: 22),
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
                ),
          ],
        );
      },
    );
  }

  Widget _buildVacationTab() {
    return StreamBuilder<List<VacationWatch>>(
      stream: _vacationWatchRepository.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load vacation watches: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SkeletonList();
        }

        final watches = snapshot.data ?? const <VacationWatch>[];
        final bulletinWatches =
            watches
                .where((watch) => watch.status != VacationWatchStatus.cancelled)
                .toList()
              ..sort((a, b) => a.startDate.compareTo(b.startDate));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.hero, AppColors.heroAlt],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Help a neighbour who is away',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick a day to check on their home. You earn karma for '
                    'every day you complete.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.heroMuted),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: _openVacationWatchPlanner,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Plan my own trip'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (bulletinWatches.isEmpty)
              const EmptyState(
                icon: Icons.cottage_outlined,
                title: 'No one is away right now',
                message:
                    'When a neighbour plans a trip, the days they need help '
                    'with appear here.',
              )
            else
              ...bulletinWatches.map(
                (watch) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _BulletinVacationCard(
                    watch: watch,
                    currentUserId: _currentUserId,
                    onClaimShift: (shift) => _claimShift(watch, shift),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bulletin'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Updates'),
              Tab(text: 'Vacation watch'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildUpdatesTab(), _buildVacationTab()]),
      ),
    );
  }
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
  all('All'),
  urgent('Urgent'),
  incidents('Incidents'),
  announcements('Announcements');

  const _Filter(this.label);
  final String label;
}
