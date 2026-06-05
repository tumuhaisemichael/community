import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PoliceStationLocatorScreen extends StatelessWidget {
  const PoliceStationLocatorScreen({super.key, this.userLocation});
  final LatLng? userLocation;

  // Mock data for police stations
  final List<Map<String, dynamic>> stations = const [
    {'name': 'Central Police Station', 'location': LatLng(0.3123, 32.5855)},
    {'name': 'Wandegeya Police', 'location': LatLng(0.3323, 32.5755)},
    {'name': 'Kira Road Police', 'location': LatLng(0.3476, 32.5925)},
  ];

  static const String _mapTilerKey = 'uWW7vmIm5gtAhwbF20VH';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Police Station Locator')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: userLocation ?? const LatLng(0.3476, 32.5825),
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}',
            additionalOptions: const {'key': _mapTilerKey},
          ),
          MarkerLayer(
            markers: stations.map((s) {
              return Marker(
                point: s['location'],
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s['name'])),
                    );
                  },
                  child: const Icon(Icons.local_police, color: Colors.blue, size: 40),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
