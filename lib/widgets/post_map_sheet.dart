import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/community_post.dart';
import '../theme/home_tone.dart';
import 'community_ui.dart';
import 'report_row.dart';

/// Pull-up sheet showing where a report was made, on a map, without leaving
/// the current page.
class PostMapSheet extends StatelessWidget {
  const PostMapSheet({super.key, required this.post, this.currentLocation});

  final CommunityPost post;
  final LatLng? currentLocation;

  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'uWW7vmIm5gtAhwbF20VH',
  );

  /// Opens the sheet if the post has a location; does nothing otherwise.
  static Future<void> show(
    BuildContext context,
    CommunityPost post, {
    LatLng? currentLocation,
  }) async {
    if (post.latitude == null || post.longitude == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Dragging is left to the map, so panning it never closes the sheet.
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          PostMapSheet(post: post, currentLocation: currentLocation),
    );
  }

  LatLng get _point => LatLng(post.latitude!, post.longitude!);

  Future<void> _directions() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${_point.latitude},${_point.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String get _title {
    final picked = post.categories.where((c) => c != PostCategory.general);
    return picked.isEmpty
        ? 'Announcement'
        : picked.map((c) => c.label).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final color = HomeTone.severity(post.severity);
    final here = currentLocation;
    final km = here == null
        ? null
        : const Distance().as(LengthUnit.Meter, here, _point) / 1000;
    final height = MediaQuery.sizeOf(context).height * .72;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: HomeTone.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: HomeTone.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(categoryIcon(post.category), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeTone.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (km != null) distanceLabel(km),
                        timeAgo(post.createdAt),
                      ].join('  •  '),
                      style: const TextStyle(
                        color: HomeTone.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: HomeTone.card,
                  side: const BorderSide(color: HomeTone.border),
                ),
                icon: const Icon(Icons.close_rounded, color: HomeTone.ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _point,
                  initialZoom: 15,
                  // Frame both the report and the user when both are known.
                  initialCameraFit: here == null
                      ? null
                      : CameraFit.bounds(
                          bounds: LatLngBounds(here, _point),
                          padding: const EdgeInsets.all(60),
                          maxZoom: 16,
                        ),
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
                      if (here != null)
                        Marker(
                          point: here,
                          width: 22,
                          height: 22,
                          child: Semantics(
                            label: 'Your location',
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: .45),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Marker(
                        point: _point,
                        width: 70,
                        height: 70,
                        child: Semantics(
                          label: '$_title report',
                          child: Center(
                            child: Container(
                              width: 70,
                              height: 70,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    color.withValues(alpha: .35),
                                    color.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  categoryIcon(post.category),
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: HomeTone.violet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _directions,
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Get directions'),
            ),
          ),
        ],
      ),
    );
  }
}
