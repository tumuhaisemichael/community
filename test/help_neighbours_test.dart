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
  _Repo(this.all);
  final List<VacationWatch> all;
  final claimed = <String>[];

  @override
  Stream<List<VacationWatch>> watchOwnedBy(String ownerId) =>
      Stream.value(const []);
  @override
  Stream<List<VacationWatch>> watchAll() => Stream.value(all);
  @override
  Future<void> claimShift({
    required VacationWatch watch,
    required String shiftId,
    required String watcherId,
    required String watcherName,
  }) async => claimed.add(shiftId);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Storage implements StorageService {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<_Repo> _open(WidgetTester tester, List<VacationWatch> all) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo(all);
  await tester.pumpWidget(
    MaterialApp(
      home: VacationWatchScreen(
        authService: _Auth(),
        repository: repo,
        storageService: _Storage(),
        karmaPoints: Stream.value(0),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Help Neighbours'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('Empty Help Neighbours tab and folding sections', (tester) async {
    await _open(tester, const []);
    expect(find.text('Support neighbours while they’re away'), findsOneWidget);
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('No one is away right now'), findsOneWidget);
    await tester.tap(find.text('View Open Days'));
    await tester.pumpAndSettle();

    // Tapping a section header folds it away and back.
    await tester.tap(find.text('Days you are covering'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing yet'), findsNothing);
    await tester.tap(find.text('Days you are covering'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping an open day signs up for it', (tester) async {
    final now = DateTime.now();
    final repo = await _open(tester, [
      VacationWatch(
        id: 'w',
        ownerId: 'aisha',
        ownerName: 'Aisha N',
        address: 'Riverside, Kampala',
        startDate: now.add(const Duration(days: 2)),
        endDate: now.add(const Duration(days: 4)),
        tasks: const [
          WatchTask(id: 't', title: 'Mail sweep', scheduleLabel: 'Daily'),
        ],
        shifts: [
          WatchShift(
            id: 's1',
            startsAt: now.add(const Duration(days: 2)),
            label: 'Coverage',
          ),
        ],
      ),
    ]);
    expect(find.text('Aisha’s home'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Sign up for ')));
    await tester.pumpAndSettle();
    expect(repo.claimed, ['s1']);
    expect(tester.takeException(), isNull);
  });
}
