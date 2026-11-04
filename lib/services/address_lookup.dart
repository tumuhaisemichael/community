import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

/// Turns a map position into a readable address using MapTiler's reverse
/// geocoding (the same provider as the map tiles).
class AddressLookup {
  AddressLookup({http.Client? client}) : _client = client ?? http.Client();

  static const String _key = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'uWW7vmIm5gtAhwbF20VH',
  );

  final http.Client _client;

  static const _areaTypes = {
    'neighbourhood',
    'place',
    'locality',
    'joint_submunicipality',
    'municipal_district',
  };
  static const _cityTypes = {'municipality', 'county', 'joint_municipality'};

  /// For example "M20, East Nsooba, Kampala". Null if nothing was found or
  /// the lookup failed.
  Future<String?> addressFor(LatLng point) async {
    try {
      final uri = Uri.parse(
        'https://api.maptiler.com/geocoding/'
        '${point.longitude},${point.latitude}.json?key=$_key&limit=1',
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final features =
          (jsonDecode(response.body) as Map<String, dynamic>)['features']
              as List<dynamic>?;
      if (features == null || features.isEmpty) return null;
      return describe(features.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Builds "street, area, city" from one geocoding result.
  static String? describe(Map<String, dynamic> feature) {
    String typeOf(Map<String, dynamic> part) =>
        (part['id'] as String? ?? '').split('.').first;

    final context = [
      for (final part in feature['context'] as List<dynamic>? ?? const [])
        part as Map<String, dynamic>,
    ];
    final parts = <String>[
      if ((feature['text'] as String?)?.isNotEmpty ?? false)
        feature['text'] as String,
      for (final part in context.where((p) => _areaTypes.contains(typeOf(p))))
        part['text'] as String,
    ];
    final city = context
        .where((p) => _cityTypes.contains(typeOf(p)))
        .map((p) => p['text'] as String)
        .lastOrNull;
    final unique = <String>[];
    for (final part in [...parts.take(2), ?city]) {
      if (!unique.contains(part)) unique.add(part);
    }
    if (unique.isEmpty) return feature['place_name'] as String?;
    return unique.join(', ');
  }
}
