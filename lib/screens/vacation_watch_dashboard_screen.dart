import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/vacation_watch.dart';
import '../repositories/vacation_watch_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class VacationWatchDashboardScreen extends StatelessWidget {
  const VacationWatchDashboardScreen({
    super.key,
    required this.authService,
    required this.repository,
  });

  final AuthService authService;
  final VacationWatchRepository repository;

  @override
  Widget build(BuildContext context) {
    final currentUserId = authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('My Watch Dashboard')),
      body: currentUserId.isEmpty
          ? const Center(child: Text('Sign in to see your watch dashboard.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .snapshots(),
              builder: (context, karmaSnapshot) {
                final karmaPoints =
                    (karmaSnapshot.data?.data()?['karmaPoints'] as num?)
                        ?.toInt() ??
                    0;

                return StreamBuilder<List<VacationWatch>>(
                  stream: repository.watchOwnedBy(currentUserId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load your watch dashboard: ${snapshot.error}',
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

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
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
                                'Your Watch Center',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Karma earned: $karmaPoints',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'See each watch plan, roster coverage, and the activity trail in a full view.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.84,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (watches.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'No vacation watch plans yet. Create one from the main Vacation Watch screen.',
                            ),
                          )
                        else
                          ...watches.map(
                            (watch) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _DashboardWatchCard(
                                watch: watch,
                                activityStream: repository.watchActivity(
                                  watch.id,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _DashboardWatchCard extends StatelessWidget {
  const _DashboardWatchCard({
    required this.watch,
    required this.activityStream,
  });

  final VacationWatch watch;
  final Stream<List<WatchActivity>> activityStream;

  Color _statusTone() {
    switch (watch.status) {
      case VacationWatchStatus.alert:
        return AppColors.alert;
      case VacationWatchStatus.completed:
        return AppColors.safe;
      case VacationWatchStatus.cancelled:
        return AppColors.mutedText;
      case VacationWatchStatus.arrivingHome:
        return AppColors.watch;
      case VacationWatchStatus.active:
        return AppColors.watch;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = _statusTone();

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
                        watch.address,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('MMM d').format(watch.startDate)} - ${DateFormat('MMM d').format(watch.endDate)}',
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
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    watch.status.name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: 'Open',
                    value: '${watch.openShiftCount}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricBlock(
                    label: 'Claimed',
                    value: '${watch.claimedShiftCount}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricBlock(
                    label: 'Completed',
                    value: '${watch.completedShiftCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Tasks', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
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
            Text(
              'Roster timeline',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...watch.shifts.map(
              (shift) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${DateFormat('EEE, MMM d').format(shift.startsAt)} • ${shift.label}',
                      ),
                    ),
                    Text(shift.watcherName ?? shift.status.name),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            StreamBuilder<List<WatchActivity>>(
              stream: activityStream,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <WatchActivity>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity feed',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('No updates logged yet.'),
                      )
                    else
                      ...items.map(
                        (item) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.actorName} • ${item.type.name}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MMM d, HH:mm',
                                    ).format(item.createdAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                              if (item.note != null &&
                                  item.note!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(item.note!),
                              ],
                              if (item.vibe != null) ...[
                                const SizedBox(height: 6),
                                Text('Vibe: ${item.vibe!.name}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
