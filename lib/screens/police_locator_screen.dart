import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/community_map.dart';
import '../widgets/community_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PoliceStationLocatorScreen extends StatefulWidget {
  const PoliceStationLocatorScreen({super.key, this.userLocation});
  final LatLng? userLocation;

  // Mock data for police stations
  static const List<({String name, LatLng location})> stations = [
    (name: 'Central Police Station', location: LatLng(0.3123, 32.5855)),
    (name: 'Wandegeya Police', location: LatLng(0.3323, 32.5755)),
    (name: 'Kira Road Police', location: LatLng(0.3476, 32.5925)),
  ];

  @override
  State<PoliceStationLocatorScreen> createState() =>
      _PoliceStationLocatorScreenState();
}

class _PoliceStationLocatorScreenState
    extends State<PoliceStationLocatorScreen> {
  static const String _mapTilerKey = 'uWW7vmIm5gtAhwbF20VH';
  static const LatLng _kampala = LatLng(0.3476, 32.5825);

  final MapController _mapController = MapController();
  int? _selected;

  double? _distanceKm(LatLng point) {
    final here = widget.userLocation;
    if (here == null) return null;
    return const Distance().as(LengthUnit.Meter, here, point) / 1000;
  }

  void _select(int index) {
    setState(() => _selected = index);
    _mapController.move(PoliceStationLocatorScreen.stations[index].location, 15);
  }

  Future<void> _directions(LatLng point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${point.latitude},${point.longitude}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stations = [
      for (var i = 0; i < PoliceStationLocatorScreen.stations.length; i++)
        (index: i, station: PoliceStationLocatorScreen.stations[i]),
    ];
    if (widget.userLocation != null) {
      stations.sort(
        (a, b) => _distanceKm(
          a.station.location,
        )!.compareTo(_distanceKm(b.station.location)!),
      );
    }
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Find police')),
      body: Column(
        children: [
          Expanded(
            child: CommunityMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.userLocation ?? _kampala,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}',
                  additionalOptions: const {'key': _mapTilerKey},
                ),
                MarkerLayer(
                  markers: [
                    for (final entry in stations)
                      Marker(
                        point: entry.station.location,
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _select(entry.index),
                          child: Icon(
                            Icons.local_police_rounded,
                            color: _selected == entry.index
                                ? AppColors.alert
                                : AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.userLocation == null
                        ? 'Stations in Kampala'
                        : 'Nearest stations',
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SettingsGroup(
                    children: [
                      for (final entry in stations)
                        ListTile(
                          selected: _selected == entry.index,
                          selectedTileColor: AppColors.watchDim,
                          onTap: () => _select(entry.index),
                          leading: const Icon(Icons.local_police_outlined),
                          title: Text(entry.station.name),
                          subtitle: _distanceKm(entry.station.location) == null
                              ? null
                              : Text(
                                  '${_distanceKm(entry.station.location)!.toStringAsFixed(1)} km away',
                                ),
                          trailing: IconButton(
                            tooltip: 'Directions to ${entry.station.name}',
                            icon: const Icon(Icons.directions_rounded),
                            onPressed: () =>
                                _directions(entry.station.location),
                          ),
                        ),
                    ],
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
