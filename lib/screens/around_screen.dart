import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class AroundScreen extends StatelessWidget {
  const AroundScreen({
    super.key,
    required this.currentUserId,
    required this.initialCenter,
  });

  static const double _nearbyRadiusKm = 2.0;
  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'uWW7vmIm5gtAhwbF20VH',
  );

  final String currentUserId;
  final LatLng initialCenter;

  String _preferredDisplayName(Map<String, dynamic> data, String fallbackId) {
    final rawName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    if (rawName != null &&
        rawName.isNotEmpty &&
        rawName.toLowerCase() != 'new member') {
      return rawName;
    }
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return fallbackId;
  }

  double _distanceKm(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
          a.latitude,
          a.longitude,
          b.latitude,
          b.longitude,
        ) /
        1000;
  }

  void _showUserDetails(
    BuildContext context, {
    required String name,
    required Map<String, dynamic> data,
    required double distanceKm,
  }) {
    final email = data['email'] as String?;
    final address = data['address'] as String?;
    final isVerified = data['isVerified'] == true;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isVerified)
                  const Icon(Icons.verified, color: Colors.blue, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Text('Distance: ${distanceKm.toStringAsFixed(2)} km away'),
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Email: $email'),
            ],
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Address: $address'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mapTilerKey.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Around')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Map disabled: set MAPTILER_KEY with --dart-define to load tiles.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Around')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load nearby users: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final nearbyUsers =
              snapshot.data?.docs.where((doc) {
                final data = doc.data();
                final latitude = (data['latitude'] as num?)?.toDouble();
                final longitude = (data['longitude'] as num?)?.toDouble();
                if (latitude == null || longitude == null) return false;

                final distance = _distanceKm(
                  initialCenter,
                  LatLng(latitude, longitude),
                );
                return distance <= _nearbyRadiusKm;
              }).toList() ??
              [];

          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}',
                      additionalOptions: const {'key': _mapTilerKey},
                      userAgentPackageName: 'com.example.community',
                    ),
                    MarkerLayer(
                      markers: [
                        ...nearbyUsers.map((doc) {
                          final data = doc.data();
                          final latitude = (data['latitude'] as num).toDouble();
                          final longitude = (data['longitude'] as num)
                              .toDouble();
                          final point = LatLng(latitude, longitude);
                          final name = doc.id == currentUserId
                              ? 'You'
                              : _preferredDisplayName(data, doc.id);
                          final distanceKm = _distanceKm(initialCenter, point);

                          return Marker(
                            point: point,
                            width: 120,
                            height: 64,
                            child: GestureDetector(
                              onTap: () => _showUserDetails(
                                context,
                                name: name,
                                data: data,
                                distanceKm: distanceKm,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Icon(
                                    doc.id == currentUserId
                                        ? Icons.location_pin
                                        : Icons.person_pin_circle,
                                    color: doc.id == currentUserId
                                        ? Colors.red
                                        : Theme.of(context).colorScheme.primary,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'People around you',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${nearbyUsers.length} people within ${_nearbyRadiusKm.toStringAsFixed(0)} km',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
