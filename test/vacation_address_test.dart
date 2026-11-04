import 'dart:async';

import 'package:community/models/vacation_watch.dart';
import 'package:community/repositories/vacation_watch_repository.dart';
import 'package:community/screens/vacation_watch_screen.dart';
import 'package:community/services/address_lookup.dart';
import 'package:community/services/auth_service.dart';
import 'package:community/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

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

class _Repo implements VacationWatchRepository {
  @override
  Stream<List<VacationWatch>> watchOwnedBy(String ownerId) =>
      Stream.value(const []);
  @override
  Stream<List<VacationWatch>> watchAll() => Stream.value(const []);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Storage implements StorageService {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Lookup implements AddressLookup {
  LatLng? asked;
  @override
  Future<String?> addressFor(LatLng point) async {
    asked = point;
    return 'M20, East Nsooba, Kampala';
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  test('Builds a short street, area, city address', () {
    final address = AddressLookup.describe({
      'text': 'M20',
      'place_name': 'M20, Uganda',
      'context': [
        {'id': 'place.1', 'text': 'East Nsooba'},
        {'id': 'major_landform.2', 'text': 'Lubigi Wetland'},
        {'id': 'joint_submunicipality.3', 'text': 'Kawempe'},
        {'id': 'joint_municipality.4', 'text': 'Kampala Capital City'},
        {'id': 'county.5', 'text': 'Kampala'},
        {'id': 'country.6', 'text': 'Uganda'},
      ],
    });
    expect(address, 'M20, East Nsooba, Kampala');
  });

  testWidgets('Picking on the map fills the address and highlights the tile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Map tiles cannot download in tests; ignore only those image errors.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    final lookup = _Lookup();
    await tester.pumpWidget(
      MaterialApp(
        home: VacationWatchScreen(
          authService: _Auth(),
          repository: _Repo(),
          storageService: _Storage(),
          karmaPoints: Stream.value(0),
          addressLookup: lookup,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'Home Address, Tap to add$')),
      findsOneWidget,
    );

    await tester.tap(find.text('Home Address'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick on map'));
    // Let the (unavailable in tests) location lookup give up for real.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    // On the picker: tap the map, then confirm.
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    // The map waits out the double-tap window before treating it as a tap.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this location'));
    await tester.pumpAndSettle();

    // Back on the sheet: the address is filled in and pinned.
    expect(lookup.asked, isNotNull);
    expect(
      find.widgetWithText(TextField, 'M20, East Nsooba, Kampala'),
      findsOneWidget,
    );
    expect(find.text('Pinned on the map'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    // The tile now shows the address and is marked as set.
    expect(
      find.bySemanticsLabel('Home Address, M20, East Nsooba, Kampala, set'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Start Date, .*[^t]$')),
      findsOneWidget,
    );
  });
}
