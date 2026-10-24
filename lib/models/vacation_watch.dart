import 'package:cloud_firestore/cloud_firestore.dart';

enum VacationWatchMode { neighborly, proCare }

enum VacationWatchStatus { active, alert, arrivingHome, completed, cancelled }

enum WatchShiftStatus { open, claimed, completed }

enum WatchActivityType { checkIn, handoff, emergency, arrival, system }

enum WatchVibe { quiet, routine, suspicious, urgent }

VacationWatchMode _watchModeFromName(String? value) {
  return VacationWatchMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => VacationWatchMode.neighborly,
  );
}

VacationWatchStatus _watchStatusFromName(String? value) {
  return VacationWatchStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => VacationWatchStatus.active,
  );
}

WatchShiftStatus _shiftStatusFromName(String? value) {
  return WatchShiftStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => WatchShiftStatus.open,
  );
}

WatchActivityType _activityTypeFromName(String? value) {
  return WatchActivityType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => WatchActivityType.system,
  );
}

WatchVibe? _watchVibeFromName(String? value) {
  if (value == null) return null;
  for (final vibe in WatchVibe.values) {
    if (vibe.name == value) return vibe;
  }
  return null;
}

DateTime _dateFromValue(dynamic value, [DateTime? fallback]) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return fallback ?? DateTime.now();
}

List<WatchShift> _fallbackShifts({
  required DateTime startDate,
  required DateTime endDate,
}) {
  final shifts = <WatchShift>[];
  var cursor = DateTime(startDate.year, startDate.month, startDate.day, 8);
  final lastDay = DateTime(endDate.year, endDate.month, endDate.day, 18);

  while (!cursor.isAfter(lastDay)) {
    shifts.add(
      WatchShift(
        id: 'legacy-${cursor.toIso8601String()}',
        startsAt: cursor,
        endsAt: cursor.add(const Duration(hours: 10)),
        label: '${cursor.month}/${cursor.day} coverage',
      ),
    );
    cursor = cursor.add(const Duration(days: 1));
  }

  return shifts;
}

class WatchTask {
  const WatchTask({
    required this.id,
    required this.title,
    required this.scheduleLabel,
    this.details,
    this.isCritical = false,
  });

  final String id;
  final String title;
  final String scheduleLabel;
  final String? details;
  final bool isCritical;

  factory WatchTask.fromMap(Map<String, dynamic> data) {
    return WatchTask(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? 'Task',
      scheduleLabel: data['scheduleLabel'] as String? ?? '',
      details: data['details'] as String?,
      isCritical: data['isCritical'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'scheduleLabel': scheduleLabel,
      'details': details,
      'isCritical': isCritical,
    };
  }
}

class WatchShift {
  const WatchShift({
    required this.id,
    required this.startsAt,
    required this.label,
    this.endsAt,
    this.watcherId,
    this.watcherName,
    this.status = WatchShiftStatus.open,
    this.claimedAt,
    this.completedAt,
    this.karmaGranted = false,
  });

  final String id;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String label;
  final String? watcherId;
  final String? watcherName;
  final WatchShiftStatus status;
  final DateTime? claimedAt;
  final DateTime? completedAt;
  final bool karmaGranted;

  bool get isOpen => status == WatchShiftStatus.open;

  bool isAssignedTo(String userId) =>
      userId.isNotEmpty && watcherId != null && watcherId == userId;

  WatchShift copyWith({
    DateTime? startsAt,
    DateTime? endsAt,
    String? label,
    String? watcherId,
    String? watcherName,
    WatchShiftStatus? status,
    DateTime? claimedAt,
    DateTime? completedAt,
    bool? karmaGranted,
    bool clearWatcher = false,
    bool clearClaimedAt = false,
    bool clearCompletedAt = false,
  }) {
    return WatchShift(
      id: id,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      label: label ?? this.label,
      watcherId: clearWatcher ? null : (watcherId ?? this.watcherId),
      watcherName: clearWatcher ? null : (watcherName ?? this.watcherName),
      status: status ?? this.status,
      claimedAt: clearClaimedAt ? null : (claimedAt ?? this.claimedAt),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      karmaGranted: karmaGranted ?? this.karmaGranted,
    );
  }

  factory WatchShift.fromMap(Map<String, dynamic> data) {
    return WatchShift(
      id: data['id'] as String? ?? '',
      startsAt: _dateFromValue(data['startsAt']),
      endsAt: data['endsAt'] == null ? null : _dateFromValue(data['endsAt']),
      label: data['label'] as String? ?? 'Coverage',
      watcherId: data['watcherId'] as String?,
      watcherName: data['watcherName'] as String?,
      status: _shiftStatusFromName(data['status'] as String?),
      claimedAt: data['claimedAt'] == null
          ? null
          : _dateFromValue(data['claimedAt']),
      completedAt: data['completedAt'] == null
          ? null
          : _dateFromValue(data['completedAt']),
      karmaGranted: data['karmaGranted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startsAt': Timestamp.fromDate(startsAt),
      'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
      'label': label,
      'watcherId': watcherId,
      'watcherName': watcherName,
      'status': status.name,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'karmaGranted': karmaGranted,
    };
  }
}

class WatchActivity {
  const WatchActivity({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.createdAt,
    this.note,
    this.photoUrls = const [],
    this.vibe,
    this.completedTaskIds = const [],
    this.shiftId,
  });

  final String id;
  final WatchActivityType type;
  final String actorId;
  final String actorName;
  final DateTime createdAt;
  final String? note;
  final List<String> photoUrls;
  final WatchVibe? vibe;
  final List<String> completedTaskIds;
  final String? shiftId;

  factory WatchActivity.fromMap(Map<String, dynamic> data, String id) {
    return WatchActivity(
      id: id,
      type: _activityTypeFromName(data['type'] as String?),
      actorId: data['actorId'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Member',
      createdAt: _dateFromValue(data['createdAt']),
      note: data['note'] as String?,
      photoUrls: List<String>.from(data['photoUrls'] ?? const []),
      vibe: _watchVibeFromName(data['vibe'] as String?),
      completedTaskIds: List<String>.from(data['completedTaskIds'] ?? const []),
      shiftId: data['shiftId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'actorId': actorId,
      'actorName': actorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'note': note,
      'photoUrls': photoUrls,
      'vibe': vibe?.name,
      'completedTaskIds': completedTaskIds,
      'shiftId': shiftId,
    };
  }
}

class VacationWatch {
  const VacationWatch({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.address,
    required this.startDate,
    required this.endDate,
    this.houseLatitude,
    this.houseLongitude,
    this.mode = VacationWatchMode.neighborly,
    this.watcherIds = const [],
    this.status = VacationWatchStatus.active,
    this.tasks = const [],
    this.shifts = const [],
    this.createdAt,
    this.updatedAt,
    this.arrivalTriggeredAt,
    this.arrivalRadiusKm = 8.0,
    this.karmaReward = 10,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String address;
  final DateTime startDate;
  final DateTime endDate;
  final double? houseLatitude;
  final double? houseLongitude;
  final VacationWatchMode mode;
  final List<String> watcherIds;
  final VacationWatchStatus status;
  final List<WatchTask> tasks;
  final List<WatchShift> shifts;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? arrivalTriggeredAt;
  final double arrivalRadiusKm;
  final int karmaReward;

  bool get isActive =>
      status == VacationWatchStatus.active ||
      status == VacationWatchStatus.alert ||
      status == VacationWatchStatus.arrivingHome;

  bool get hasLocation => houseLatitude != null && houseLongitude != null;

  int get openShiftCount =>
      shifts.where((shift) => shift.status == WatchShiftStatus.open).length;

  int get claimedShiftCount =>
      shifts.where((shift) => shift.status == WatchShiftStatus.claimed).length;

  int get completedShiftCount => shifts
      .where((shift) => shift.status == WatchShiftStatus.completed)
      .length;

  double get completionRatio {
    if (shifts.isEmpty) return 0;
    return completedShiftCount / shifts.length;
  }

  List<WatchShift> assignedTo(String userId) {
    return shifts.where((shift) => shift.isAssignedTo(userId)).toList();
  }

  factory VacationWatch.fromMap(Map<String, dynamic> data, String id) {
    final startDate = _dateFromValue(data['startDate']);
    final endDate = _dateFromValue(data['endDate']);
    final parsedShifts = (data['shifts'] as List<dynamic>? ?? const [])
        .map(
          (shift) => WatchShift.fromMap(
            Map<String, dynamic>.from(shift as Map<dynamic, dynamic>),
          ),
        )
        .toList();

    return VacationWatch(
      id: id,
      ownerId: data['ownerId'] as String? ?? data['userId'] as String? ?? '',
      ownerName:
          data['ownerName'] as String? ?? data['userName'] as String? ?? '',
      address: data['address'] as String? ?? '',
      startDate: startDate,
      endDate: endDate,
      houseLatitude: (data['houseLatitude'] as num?)?.toDouble(),
      houseLongitude: (data['houseLongitude'] as num?)?.toDouble(),
      mode: _watchModeFromName(data['mode'] as String?),
      watcherIds: List<String>.from(data['watcherIds'] ?? const []),
      status: _watchStatusFromName(data['status'] as String?),
      tasks: (data['tasks'] as List<dynamic>? ?? const [])
          .map(
            (task) => WatchTask.fromMap(
              Map<String, dynamic>.from(task as Map<dynamic, dynamic>),
            ),
          )
          .toList(),
      shifts: parsedShifts.isEmpty
          ? _fallbackShifts(startDate: startDate, endDate: endDate)
          : parsedShifts,
      createdAt: data['createdAt'] == null
          ? null
          : _dateFromValue(data['createdAt']),
      updatedAt: data['updatedAt'] == null
          ? null
          : _dateFromValue(data['updatedAt']),
      arrivalTriggeredAt: data['arrivalTriggeredAt'] == null
          ? null
          : _dateFromValue(data['arrivalTriggeredAt']),
      arrivalRadiusKm: (data['arrivalRadiusKm'] as num?)?.toDouble() ?? 8.0,
      karmaReward: (data['karmaReward'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerName': ownerName,
      'address': address,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'houseLatitude': houseLatitude,
      'houseLongitude': houseLongitude,
      'mode': mode.name,
      'watcherIds': watcherIds,
      'status': status.name,
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'shifts': shifts.map((shift) => shift.toMap()).toList(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'arrivalTriggeredAt': arrivalTriggeredAt != null
          ? Timestamp.fromDate(arrivalTriggeredAt!)
          : null,
      'arrivalRadiusKm': arrivalRadiusKm,
      'karmaReward': karmaReward,
    };
  }
}
