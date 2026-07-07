import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

class VacationHousePickerScreen extends StatefulWidget {
  const VacationHousePickerScreen({
    super.key,
    required this.initialCenter,
    this.initialSelection,
  });

  final LatLng initialCenter;
  final LatLng? initialSelection;

  @override
  State<VacationHousePickerScreen> createState() =>
      _VacationHousePickerScreenState();
}

class _VacationHousePickerScreenState extends State<VacationHousePickerScreen> {
  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'uWW7vmIm5gtAhwbF20VH',
  );

  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = _selectedLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick House Location'),
        actions: [
          TextButton(
            onPressed: selectedLocation == null
                ? null
                : () => Navigator.pop(context, selectedLocation),
            child: const Text('Use Pin'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: selectedLocation ?? widget.initialCenter,
                initialZoom: 16,
                onTap: (_, point) {
                  setState(() => _selectedLocation = point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$_mapTilerKey',
                  userAgentPackageName: 'community.app',
                ),
                if (selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: selectedLocation,
                        width: 120,
                        height: 72,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text('House location'),
                            ),
                            const SizedBox(height: 4),
                            const Icon(
                              Icons.location_pin,
                              color: AppColors.alert,
                              size: 34,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap the map to place the house pin',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  selectedLocation == null
                      ? 'No location selected yet.'
                      : 'Lat ${selectedLocation.latitude.toStringAsFixed(5)}, '
                            'Lng ${selectedLocation.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: selectedLocation == null
                      ? null
                      : () => Navigator.pop(context, selectedLocation),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm house location'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
