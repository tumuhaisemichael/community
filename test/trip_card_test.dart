import 'package:community/models/vacation_watch.dart';
import 'package:community/repositories/vacation_watch_repository.dart';
import 'package:community/screens/vacation_watch_screen.dart';
import 'package:community/services/auth_service.dart';
import 'package:community/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  String get uid => 'me';
  @override
  String? get displayName => 'Mic';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthService {
  @override
  User? get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Repo implements VacationWatchRepository {
  final now = DateTime.now();
  @override
  Stream<List<VacationWatch>> watchOwnedBy(String ownerId) => Stream.value([
    VacationWatch(
      id: '1',
      ownerId: 'me',
      ownerName: 'Mic',
      address: 'Muwafu Curve, Village 10, Kampala',
      startDate: now.subtract(const Duration(hours: 2)),
      endDate: now.add(const Duration(days: 2)),
      karmaReward: 15,
      tasks: const [
        WatchTask(id: 'a', title: 'Trash bins', scheduleLabel: 'Set out'),
        WatchTask(
          id: 'b',
          title: 'Mail sweep',
          scheduleLabel: 'Daily',
          isCritical: true,
        ),
      ],
      shifts: [
        for (var i = 0; i < 3; i++)
          WatchShift(
            id: '$i',
            startsAt: now.add(Duration(days: i)),
            label: 'Coverage',
          ),
      ],
    ),
  ]);
  @override
  Stream<List<VacationWatch>> watchAll() => Stream.value(const []);
  @override
  Stream<List<WatchActivity>> watchActivity(String watchId) => Stream.value([
    WatchActivity(
      id: 'x',
      type: WatchActivityType.system,
      actorId: 'me',
      actorName: 'Mic',
      createdAt: now,
    ),
  ]);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Storage implements StorageService {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  testWidgets('Trip card opens and closes from its header', (tester) async {
    tester.view.physicalSize = const Size(390, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: VacationWatchScreen(
          authService: _Auth(),
          repository: _Repo(),
          storageService: _Storage(),
          karmaPoints: Stream.value(0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Starts open: full breakdown visible.
    expect(find.text('Roster Timeline'), findsOneWidget);
    expect(find.text('15 karma / shift'), findsOneWidget);
    expect(find.text('1 update logged'), findsOneWidget);
    expect(find.text('Cancel Watch'), findsOneWidget);

    // Tap the header: closes to a one-line summary.
    await tester.tap(find.text('Muwafu Curve, Village 10, Kampala'));
    await tester.pumpAndSettle();
    expect(find.text('Roster Timeline'), findsNothing);
    expect(find.textContaining('3 open  ·  0 claimed'), findsOneWidget);

    // Tap again: opens.
    await tester.tap(find.text('Muwafu Curve, Village 10, Kampala'));
    await tester.pumpAndSettle();
    expect(find.text('Roster Timeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
