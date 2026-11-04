import 'dart:async';

import 'package:community/models/vacation_watch.dart';
import 'package:community/repositories/vacation_watch_repository.dart';
import 'package:community/screens/vacation_watch_screen.dart';
import 'package:community/services/auth_service.dart';
import 'package:community/services/storage_service.dart';
import 'package:community/widgets/community_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  String get uid => 'me';
  @override
  String? get displayName => 'Maya';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthService {
  @override
  User? get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

/// Counts how often the screen opens (and listens to) each stream.
class _Repo implements VacationWatchRepository {
  int ownedOpened = 0;
  int ownedListens = 0;
  int allListens = 0;

  @override
  Stream<List<VacationWatch>> watchOwnedBy(String ownerId) {
    ownedOpened++;
    // Single-subscription, like Firestore: listening twice would throw.
    final controller = StreamController<List<VacationWatch>>(
      onListen: () => ownedListens++,
    );
    controller.add(const []);
    return controller.stream;
  }

  @override
  Stream<List<VacationWatch>> watchAll() {
    final controller = StreamController<List<VacationWatch>>(
      onListen: () => allListens++,
    );
    controller.add(const []);
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Storage implements StorageService {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  testWidgets('Switching Neighbours / Paid Carer only redraws the planner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
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
    expect(find.text('No trips planned yet'), findsOneWidget);

    for (final option in ['Paid Carer', 'Neighbours', 'Paid Carer']) {
      await tester.tap(find.text(option));
      await tester.pump();
      // No loading placeholder, and the trips section stays put.
      expect(find.byType(SkeletonBox), findsNothing);
      expect(find.text('No trips planned yet'), findsOneWidget);
    }
    expect(find.textContaining('Paid carers are arranged'), findsOneWidget);
    expect(repo.ownedOpened, 1);
    expect(repo.ownedListens, 1);

    // Switching tabs away and back reuses the same connections.
    await tester.tap(find.text('Help Neighbours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Trips').first);
    // Check every frame of the slide back: never a loading placeholder.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(SkeletonBox), findsNothing);
    }
    await tester.pumpAndSettle();
    expect(find.text('No trips planned yet'), findsOneWidget);
    expect(repo.ownedListens, 1);
    expect(repo.allListens, 1);
    expect(tester.takeException(), isNull);
  });
}
