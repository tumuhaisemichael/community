import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class UserLocationTrackingService {
  UserLocationTrackingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const Duration trackingInterval = Duration(minutes: 5);

  final FirebaseFirestore _firestore;
  Timer? _timer;
  bool _isUpdating = false;

  Future<void> startTracking({
    required String userId,
    required void Function(LatLng location) onLocation,
    required void Function(String message) onError,
  }) async {
    _timer?.cancel();

    await _updateLocation(
      userId: userId,
      onLocation: onLocation,
      onError: onError,
    );

    _timer = Timer.periodic(trackingInterval, (_) {
      _updateLocation(userId: userId, onLocation: onLocation, onError: onError);
    });
  }

  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _updateLocation({
    required String userId,
    required void Function(LatLng location) onLocation,
    required void Function(String message) onError,
  }) async {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError(
          'Location services are off. Turn them on to share your position.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        onError(
          'Location permission denied. Enable it to share your position.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        onError(
          'Location permission is permanently denied. Enable it in settings to share your position.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);

      await _firestore.collection('users').doc(userId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      onLocation(location);
    } catch (_) {
      onError('Could not fetch your location right now. Please try again.');
    } finally {
      _isUpdating = false;
    }
  }
}
