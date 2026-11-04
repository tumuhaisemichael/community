import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/vacation_watch.dart';
import '../theme/home_tone.dart';

/// Building blocks shared by the My Trips cards and the Trip Dashboard.

/// "Nov 5 – Nov 7 (3 days)".
String tripDateRange(VacationWatch w) {
  final short = DateFormat('MMM d');
  final days = w.endDate.difference(w.startDate).inDays + 1;
  return '${short.format(w.startDate)} – ${short.format(w.endDate)} '
      '($days day${days == 1 ? '' : 's'})';
}

/// Label, text colour and tint for a trip's current state.
(String, Color, Color) tripStatus(VacationWatch watch) {
  final now = DateTime.now();
  if (watch.status == VacationWatchStatus.cancelled) {
    return ('Cancelled', HomeTone.muted, const Color(0xFFEFEDF5));
  }
  if (watch.status == VacationWatchStatus.alert) {
    return ('Alert', HomeTone.red, HomeTone.redDim);
  }
  if (watch.status == VacationWatchStatus.arrivingHome) {
    return ('Arriving home', HomeTone.blue, HomeTone.blueDim);
  }
  if (watch.status == VacationWatchStatus.completed ||
      watch.endDate.isBefore(DateTime(now.year, now.month, now.day))) {
    return ('Completed', HomeTone.muted, const Color(0xFFEFEDF5));
  }
  if (watch.startDate.isAfter(now)) {
    return ('Upcoming', HomeTone.violet, HomeTone.violetDim);
  }
  return ('Active', HomeTone.green, HomeTone.greenDim);
}

/// Sheet listing each task with its schedule and instructions.
void showTaskDetailsSheet(BuildContext context, VacationWatch watch) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: HomeTone.card,
    isScrollControlled: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .75,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const Text(
            'Tasks for neighbours',
            style: TextStyle(
              color: HomeTone.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (final task in watch.tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaskIcon(task: task),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title +
                              (task.isCritical ? '  ·  Important' : ''),
                          style: const TextStyle(
                            color: HomeTone.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          task.scheduleLabel,
                          style: const TextStyle(
                            color: HomeTone.muted,
                            fontSize: 12.5,
                          ),
                        ),
                        if ((task.details ?? '').isNotEmpty)
                          Text(
                            task.details!,
                            style: const TextStyle(
                              color: HomeTone.ink,
                              fontSize: 12.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class TripMetric extends StatelessWidget {
  const TripMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = HomeTone.violet,
    this.tint = const Color(0xFFF3EFFC),
  });
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $label',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                '$value',
                style: const TextStyle(
                  color: HomeTone.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: HomeTone.ink, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

IconData taskIconFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('trash') || t.contains('bin')) {
    return Icons.delete_outline_rounded;
  }
  if (t.contains('mail')) return Icons.mail_outline_rounded;
  if (t.contains('package') || t.contains('parcel')) {
    return Icons.inventory_2_outlined;
  }
  if (t.contains('plant') || t.contains('water')) {
    return Icons.local_florist_outlined;
  }
  if (t.contains('light')) return Icons.lightbulb_outline_rounded;
  if (t.contains('pet')) return Icons.pets_rounded;
  return Icons.check_circle_outline_rounded;
}

class TaskIcon extends StatelessWidget {
  const TaskIcon({super.key, required this.task});
  final WatchTask task;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: task.isCritical ? const Color(0xFFFDE7F0) : HomeTone.violetDim,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(
      taskIconFor(task.title),
      size: 19,
      color: task.isCritical ? const Color(0xFFBE185D) : HomeTone.violet,
    ),
  );
}

/// Violet chip for routine tasks, pink for important ones.
class TaskChip extends StatelessWidget {
  const TaskChip({super.key, required this.task});
  final WatchTask task;

  @override
  Widget build(BuildContext context) {
    final critical = task.isCritical;
    final fg = critical ? const Color(0xFFBE185D) : HomeTone.violet;
    return Semantics(
      label: '${task.title}${critical ? ', important' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
        decoration: BoxDecoration(
          color: critical ? const Color(0xFFFDE7F0) : const Color(0xFFF0EAFE),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(taskIconFor(task.title), size: 17, color: fg),
            const SizedBox(width: 7),
            Text(
              task.title,
              style: const TextStyle(
                color: HomeTone.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RosterTimeline extends StatelessWidget {
  const RosterTimeline({super.key, required this.shifts});
  final List<WatchShift> shifts;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < shifts.length; i++)
        RosterRow(
          shift: shifts[i],
          isFirst: i == 0,
          isLast: i == shifts.length - 1,
        ),
    ],
  );
}

class RosterRow extends StatelessWidget {
  const RosterRow({
    super.key,
    required this.shift,
    required this.isFirst,
    required this.isLast,
  });
  final WatchShift shift;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (shift.status) {
      WatchShiftStatus.open => (
        'Open',
        HomeTone.muted,
        const Color(0xFFEFEDF5),
      ),
      WatchShiftStatus.claimed => (
        'Claimed',
        HomeTone.violet,
        HomeTone.violetDim,
      ),
      WatchShiftStatus.completed => ('Done', HomeTone.green, HomeTone.greenDim),
    };
    final who = shift.watcherName?.trim();
    final subtitle = [
      shift.label.trim().isEmpty ? 'Coverage' : shift.label.trim(),
      if (who != null && who.isNotEmpty) who,
    ].join(' · ');
    const line = Color(0xFFD8CCF7);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dot with the connecting line above and below it.
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : line,
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: shift.status == WatchShiftStatus.open
                        ? HomeTone.violet.withValues(alpha: .55)
                        : HomeTone.violet,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEE, MMM d').format(shift.startsAt),
                          style: const TextStyle(
                            color: HomeTone.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HomeTone.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.item});
  final WatchActivity item;

  @override
  Widget build(BuildContext context) {
    final emergency = item.type == WatchActivityType.emergency;
    final accent = emergency ? HomeTone.red : HomeTone.violet;
    final name = item.actorName.trim().isEmpty ? 'Neighbour' : item.actorName;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: emergency ? HomeTone.redDim : const Color(0xFFF7F4FD),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: accent.withValues(alpha: .14),
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
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
                                  '$name · ${item.type.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: HomeTone.ink,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat(
                                  'MMM d, HH:mm',
                                ).format(item.createdAt),
                                style: const TextStyle(
                                  color: HomeTone.muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          if ((item.note ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.note!.trim(),
                              style: const TextStyle(
                                color: HomeTone.ink,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                          if (item.vibe != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Vibe: ${item.vibe!.label}',
                              style: const TextStyle(
                                color: HomeTone.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
