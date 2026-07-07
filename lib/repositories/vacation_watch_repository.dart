import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vacation_watch.dart';

class VacationWatchRepository {
  VacationWatchRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _watches =>
      _firestore.collection('vacation_watches');

  DocumentReference<Map<String, dynamic>> _watchDoc(String watchId) =>
      _watches.doc(watchId);

  Stream<List<VacationWatch>> watchAll() {
    return _watches.snapshots().map((snapshot) {
      final watches = snapshot.docs
          .map((doc) => VacationWatch.fromMap(doc.data(), doc.id))
          .toList();
      watches.sort((a, b) => b.startDate.compareTo(a.startDate));
      return watches;
    });
  }

  Stream<List<VacationWatch>> watchOwnedBy(String ownerId) {
    return _watches.where('ownerId', isEqualTo: ownerId).snapshots().map((
      snapshot,
    ) {
      final watches = snapshot.docs
          .map((doc) => VacationWatch.fromMap(doc.data(), doc.id))
          .toList();
      watches.sort((a, b) => b.startDate.compareTo(a.startDate));
      return watches;
    });
  }

  Stream<List<WatchActivity>> watchActivity(String watchId) {
    return _watchDoc(watchId)
        .collection('activity')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WatchActivity.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<String> createWatch(VacationWatch watch) async {
    final watchRef = _watches.doc();
    final activityRef = watchRef.collection('activity').doc();

    final batch = _firestore.batch();
    batch.set(watchRef, watch.toMap());
    batch.set(activityRef, {
      'type': WatchActivityType.system.name,
      'actorId': watch.ownerId,
      'actorName': watch.ownerName,
      'createdAt': FieldValue.serverTimestamp(),
      'note':
          '${watch.ownerName} created a ${watch.mode == VacationWatchMode.neighborly ? 'Neighborly Help' : 'Pro Care'} watch plan.',
      'photoUrls': const [],
      'completedTaskIds': const [],
    });
    await batch.commit();
    return watchRef.id;
  }

  Future<void> claimShift({
    required VacationWatch watch,
    required String shiftId,
    required String watcherId,
    required String watcherName,
  }) async {
    final watchRef = _watchDoc(watch.id);
    final activityRef = watchRef.collection('activity').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(watchRef);
      final current = VacationWatch.fromMap(snapshot.data() ?? {}, snapshot.id);
      final updatedShifts = current.shifts.map((shift) {
        if (shift.id != shiftId) return shift;
        if (!shift.isOpen) {
          throw StateError('This shift has already been claimed.');
        }
        return shift.copyWith(
          status: WatchShiftStatus.claimed,
          watcherId: watcherId,
          watcherName: watcherName,
          claimedAt: DateTime.now(),
        );
      }).toList();

      final watcherIds = {...current.watcherIds, watcherId}.toList();

      transaction.update(watchRef, {
        'shifts': updatedShifts.map((shift) => shift.toMap()).toList(),
        'watcherIds': watcherIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityRef, {
        'type': WatchActivityType.system.name,
        'actorId': watcherId,
        'actorName': watcherName,
        'createdAt': FieldValue.serverTimestamp(),
        'note': '$watcherName claimed a coverage shift.',
        'photoUrls': const [],
        'completedTaskIds': const [],
        'shiftId': shiftId,
      });
    });
  }

  Future<void> releaseShift({
    required VacationWatch watch,
    required String shiftId,
    required String watcherId,
    required String watcherName,
  }) async {
    final watchRef = _watchDoc(watch.id);
    final activityRef = watchRef.collection('activity').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(watchRef);
      final current = VacationWatch.fromMap(snapshot.data() ?? {}, snapshot.id);
      final updatedShifts = current.shifts.map((shift) {
        if (shift.id != shiftId) return shift;
        if (shift.watcherId != watcherId ||
            shift.status == WatchShiftStatus.completed) {
          throw StateError('Only your claimed shift can be released.');
        }
        return shift.copyWith(
          status: WatchShiftStatus.open,
          karmaGranted: false,
          clearWatcher: true,
          clearClaimedAt: true,
          clearCompletedAt: true,
        );
      }).toList();

      final watcherIds = updatedShifts
          .where(
            (shift) => shift.watcherId != null && shift.watcherId!.isNotEmpty,
          )
          .map((shift) => shift.watcherId!)
          .toSet()
          .toList();

      transaction.update(watchRef, {
        'shifts': updatedShifts.map((shift) => shift.toMap()).toList(),
        'watcherIds': watcherIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityRef, {
        'type': WatchActivityType.system.name,
        'actorId': watcherId,
        'actorName': watcherName,
        'createdAt': FieldValue.serverTimestamp(),
        'note': '$watcherName released a claimed shift.',
        'photoUrls': const [],
        'completedTaskIds': const [],
        'shiftId': shiftId,
      });
    });
  }

  Future<void> submitCheckIn({
    required VacationWatch watch,
    required String shiftId,
    required String actorId,
    required String actorName,
    required String note,
    required WatchVibe vibe,
    required List<String> completedTaskIds,
    List<String> photoUrls = const [],
  }) async {
    final activityRef = _watchDoc(watch.id).collection('activity').doc();
    await activityRef.set({
      'type': WatchActivityType.checkIn.name,
      'actorId': actorId,
      'actorName': actorName,
      'createdAt': FieldValue.serverTimestamp(),
      'note': note,
      'photoUrls': photoUrls,
      'vibe': vibe.name,
      'completedTaskIds': completedTaskIds,
      'shiftId': shiftId,
    });
    await _watchDoc(
      watch.id,
    ).update({'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> completeShift({
    required VacationWatch watch,
    required String shiftId,
    required String actorId,
    required String actorName,
    required String note,
    List<String> photoUrls = const [],
  }) async {
    final watchRef = _watchDoc(watch.id);
    final userRef = _firestore.collection('users').doc(actorId);
    final activityRef = watchRef.collection('activity').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(watchRef);
      final current = VacationWatch.fromMap(snapshot.data() ?? {}, snapshot.id);
      bool found = false;
      final updatedShifts = current.shifts.map((shift) {
        if (shift.id != shiftId) return shift;
        found = true;
        if (shift.watcherId != actorId) {
          throw StateError(
            'Only the assigned watcher can complete this shift.',
          );
        }
        if (shift.status == WatchShiftStatus.completed) {
          return shift;
        }
        return shift.copyWith(
          status: WatchShiftStatus.completed,
          completedAt: DateTime.now(),
          karmaGranted: true,
        );
      }).toList();

      if (!found) {
        throw StateError('Shift not found.');
      }

      transaction.update(watchRef, {
        'shifts': updatedShifts.map((shift) => shift.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(userRef, {
        'karmaPoints': FieldValue.increment(watch.karmaReward),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(activityRef, {
        'type': WatchActivityType.handoff.name,
        'actorId': actorId,
        'actorName': actorName,
        'createdAt': FieldValue.serverTimestamp(),
        'note': note,
        'photoUrls': photoUrls,
        'completedTaskIds': const [],
        'shiftId': shiftId,
      });
    });
  }

  Future<void> raiseEmergency({
    required VacationWatch watch,
    required String actorId,
    required String actorName,
    required String note,
  }) async {
    final watchRef = _watchDoc(watch.id);
    final activityRef = watchRef.collection('activity').doc();
    await _firestore.runTransaction((transaction) async {
      transaction.update(watchRef, {
        'status': VacationWatchStatus.alert.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityRef, {
        'type': WatchActivityType.emergency.name,
        'actorId': actorId,
        'actorName': actorName,
        'createdAt': FieldValue.serverTimestamp(),
        'note': note,
        'photoUrls': const [],
        'completedTaskIds': const [],
      });
    });
  }

  Future<void> markOwnerArrivingHome({
    required VacationWatch watch,
    required String actorId,
    required String actorName,
  }) async {
    if (!watch.isActive) return;

    final watchRef = _watchDoc(watch.id);
    final activityRef = watchRef.collection('activity').doc();
    final thankYouNames = watch.shifts
        .where(
          (shift) => shift.watcherName != null && shift.watcherName!.isNotEmpty,
        )
        .map((shift) => shift.watcherName!)
        .toSet()
        .toList();

    await _firestore.runTransaction((transaction) async {
      transaction.update(watchRef, {
        'status': VacationWatchStatus.completed.name,
        'arrivalTriggeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(activityRef, {
        'type': WatchActivityType.arrival.name,
        'actorId': actorId,
        'actorName': actorName,
        'createdAt': FieldValue.serverTimestamp(),
        'note': thankYouNames.isEmpty
            ? '$actorName is close to home. Vacation watch closed.'
            : '$actorName is close to home. Thank you ${thankYouNames.join(', ')} for covering the watch.',
        'photoUrls': const [],
        'completedTaskIds': const [],
      });
    });
  }

  Future<void> cancelWatch(String watchId) {
    return _watchDoc(watchId).update({
      'status': VacationWatchStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
