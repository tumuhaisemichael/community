import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/community_post.dart';
import '../models/vacation_watch.dart';
import '../repositories/post_repository.dart';
import '../repositories/vacation_watch_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
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

  Widget _buildUpdatesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: 'Share an announcement...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _isSubmitting ? null : _submitPost,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CommunityPost>>(
            stream: widget.postRepository.getPostsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final posts = snapshot.data ?? [];

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: posts.length,
                itemBuilder: (context, index) => PostCard(
                  post: posts[index],
                  authService: widget.authService,
                  postRepository: widget.postRepository,
                ),
              );
            },
          ),
        ),
      ],
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
          return const Center(child: CircularProgressIndicator());
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
                gradient: const LinearGradient(
                  colors: [AppColors.watch, AppColors.ink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vacation Watch Board',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is where neighbors see who is going away, review open coverage days, and claim the exact day they want to help with.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.84),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: _openVacationWatchPlanner,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Create a vacation watch'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (bulletinWatches.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'No active vacation watches yet. When someone plans a trip, their coverage days will appear here.',
                ),
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
          title: const Text('Community Bulletin'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Updates'),
              Tab(text: 'Vacation Watch'),
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
              _ShiftInfoRow(label: 'Status', value: shift.status.name),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.watchDim,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${watch.karmaReward} karma/day',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isClosed ? AppColors.safeDim : AppColors.watchDim),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isClosed
                    ? watch.status.name
                    : (watch.status == VacationWatchStatus.completed
                          ? 'reopened'
                          : watch.status.name),
                style: Theme.of(context).textTheme.labelSmall,
              ),
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
