import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../theme/home_tone.dart';
import '../widgets/community_ui.dart';
import '../widgets/hero_header.dart';
import '../widgets/home_overview.dart';
import '../widgets/post_media.dart';
import '../widgets/report_row.dart';
import 'police_locator_screen.dart';

enum _MapFilter { all, urgent, reports, people, police }

/// Map tab: people, reports and police stations around the user, with a
/// pull-up sheet summarising recent reports nearby.
class AroundScreen extends StatefulWidget {
  const AroundScreen({
    super.key,
    required this.currentUserId,
    required this.currentLocation,
    required this.fallbackCenter,
    required this.postRepository,
    required this.userInitial,
    required this.onOpenBulletin,
    required this.onOpenMe,
    this.usersStream,
  });

  final String currentUserId;

  /// Null until the device location is known.
  final LatLng? currentLocation;
  final LatLng fallbackCenter;
  final PostRepository postRepository;
  final String userInitial;
  final VoidCallback onOpenBulletin;
  final VoidCallback onOpenMe;

  /// Neighbours' user documents; defaults to the Firestore `users`
  /// collection. Tests pass their own.
  final Stream<QuerySnapshot<Map<String, dynamic>>>? usersStream;

  @override
  State<AroundScreen> createState() => _AroundScreenState();
}

class _AroundScreenState extends State<AroundScreen> {
  double get _nearbyRadiusKm => AreaPulseCard.radiusKm;
  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'uWW7vmIm5gtAhwbF20VH',
  );
  static const double _sheetMin = .16;
  static const double _sheetStart = .42;

  /// Neighbours who updated their location this recently show as online.
  static const Duration _onlineWindow = Duration(minutes: 15);

  static const List<Color> _avatarColors = [
    Color(0xFF7C3AED),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
  ];

  final MapController _map = MapController();
  final DraggableScrollableController _sheet = DraggableScrollableController();
  late final Stream<List<CommunityPost>> _posts = widget.postRepository
      .getPostsStream();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _users =
      widget.usersStream ??
      FirebaseFirestore.instance.collection('users').snapshots();

  _MapFilter _filter = _MapFilter.all;
  bool _satellite = false;

  LatLng get _center => widget.currentLocation ?? widget.fallbackCenter;

  @override
  void dispose() {
    _map.dispose();
    _sheet.dispose();
    super.dispose();
  }

  double _distanceKm(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      ) /
      1000;

  LatLng? _pointOf(CommunityPost post) =>
      post.latitude == null || post.longitude == null
      ? null
      : LatLng(post.latitude!, post.longitude!);

  String _displayName(Map<String, dynamic> data, String fallbackId) {
    final rawName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    if (rawName != null &&
        rawName.isNotEmpty &&
        rawName.toLowerCase() != 'new member') {
      return rawName;
    }
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return fallbackId;
  }

  bool _isOnline(Map<String, dynamic> data) {
    final updated = data['locationUpdatedAt'];
    return updated is Timestamp &&
        DateTime.now().difference(updated.toDate()) < _onlineWindow;
  }

  void _zoomBy(double delta) {
    final camera = _map.camera;
    _map.move(camera.center, (camera.zoom + delta).clamp(3, 19));
  }

  void _focus(LatLng point) {
    _map.move(point, 16);
    if (_sheet.isAttached) {
      _sheet.animateTo(
        _sheetMin,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _directions(LatLng point) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${point.latitude},${point.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ---------------------------------------------------------------- details

  Future<void> _showSheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: HomeTone.card,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: child,
      ),
    ),
  );

  TextStyle get _titleStyle => const TextStyle(
    color: HomeTone.ink,
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );
  TextStyle get _bodyStyle =>
      const TextStyle(color: HomeTone.muted, fontSize: 13.5, height: 1.4);

  ButtonStyle get _primaryButton => FilledButton.styleFrom(
    backgroundColor: HomeTone.violet,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  void _showPerson(String name, Map<String, dynamic> data, LatLng point) {
    final address = (data['address'] as String?)?.trim();
    final verified = data['isVerified'] == true;
    final online = _isOnline(data);
    _showSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: HomeTone.violetDim,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(
                    color: HomeTone.violet,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: _titleStyle)),
              if (verified)
                const Icon(Icons.verified, color: HomeTone.violet, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${distanceLabel(_distanceKm(_center, point))}'
            '${online ? ' • Online now' : ''}',
            style: _bodyStyle,
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(address, style: _bodyStyle),
          ],
        ],
      ),
    );
  }

  void _showPost(CommunityPost post) {
    final point = _pointOf(post);
    final color = HomeTone.severity(post.severity);
    _showSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                child: Text(
                  '${post.categoriesLabel} · ${post.severity.label}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PostImages(post: post, height: 150),
          const SizedBox(height: 14),
          Text(
            post.content,
            style: const TextStyle(
              color: HomeTone.ink,
              fontSize: 14.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (point != null) distanceLabel(_distanceKm(_center, point)),
              timeAgo(post.createdAt),
              post.isAnonymous ? 'Anonymous' : post.authorName,
            ].join(' • '),
            style: _bodyStyle,
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: _primaryButton,
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenBulletin();
            },
            child: const Text('Open in bulletin'),
          ),
        ],
      ),
    );
  }

  void _showStation(String name, LatLng point) {
    _showSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HomeTone.blueDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_police_rounded,
                  color: HomeTone.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: _titleStyle)),
            ],
          ),
          const SizedBox(height: 12),
          Text(distanceLabel(_distanceKm(_center, point)), style: _bodyStyle),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: _primaryButton,
            onPressed: () => _directions(point),
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Get directions'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- markers

  List<Marker> _policeMarkers() => [
    for (final station in PoliceStationLocatorScreen.stations)
      Marker(
        point: station.location,
        width: 46,
        height: 46,
        child: _RoundPin(
          color: HomeTone.blue,
          icon: Icons.local_police_rounded,
          label: station.name,
          onTap: () => _showStation(station.name, station.location),
        ),
      ),
  ];

  List<Marker> _peopleMarkers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final markers = <Marker>[];
    for (final doc in docs) {
      if (doc.id == widget.currentUserId) continue;
      final data = doc.data();
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final point = LatLng(lat, lng);
      if (_distanceKm(_center, point) > _nearbyRadiusKm) continue;
      final name = _displayName(data, doc.id);
      markers.add(
        Marker(
          point: point,
          width: 52,
          height: 57,
          alignment: Alignment.topCenter,
          child: _PersonPin(
            name: name,
            color: _avatarColors[doc.id.hashCode.abs() % _avatarColors.length],
            online: _isOnline(data),
            onTap: () => _showPerson(name, data, point),
          ),
        ),
      );
    }
    return markers;
  }

  List<Marker> _reportMarkers(List<CommunityPost> posts) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final dayAgo = DateTime.now().subtract(const Duration(hours: 24));
    final markers = <Marker>[];
    // Oldest first so the newest reports draw on top.
    for (final post in posts.reversed) {
      final point = _pointOf(post);
      if (point == null || post.createdAt.isBefore(since)) continue;
      if (_filter == _MapFilter.urgent && !post.severity.isSerious) continue;
      final serious = post.severity.isSerious;
      markers.add(
        Marker(
          point: point,
          width: serious ? 70 : 46,
          height: serious ? 70 : 46,
          child: Opacity(
            opacity: post.createdAt.isBefore(dayAgo) ? .6 : 1,
            child: _RoundPin(
              color: HomeTone.severity(post.severity),
              icon: categoryIcon(post.category),
              label: '${post.categoriesLabel} report',
              glow: serious,
              onTap: () => _showPost(post),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: HomeTone.canvas,
        child: StreamBuilder<List<CommunityPost>>(
          stream: _posts,
          builder: (context, postSnap) {
            final posts = postSnap.data ?? const <CommunityPost>[];
            final recent = recentNearby(posts, widget.currentLocation)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return Column(
              children: [
                HeroHeader(
                  title: 'Map',
                  subtitle: 'People, reports and activity around you.',
                  initial: widget.userInitial,
                  hasAlerts: recent.any((p) => p.severity.isSerious),
                  onOpenBulletin: widget.onOpenBulletin,
                  onOpenMe: widget.onOpenMe,
                  bottom: _FilterBar(
                    selected: _filter,
                    onSelect: (filter) => setState(() => _filter = filter),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _users,
                    builder: (context, userSnap) => Stack(
                      children: [
                        Positioned.fill(
                          child: _buildMap(posts, userSnap.data?.docs ?? []),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _MapControls(
                            satellite: _satellite,
                            canRecenter: widget.currentLocation != null,
                            onRecenter: () => _map.move(_center, 14),
                            onToggleLayer: () =>
                                setState(() => _satellite = !_satellite),
                            onZoomIn: () => _zoomBy(1),
                            onZoomOut: () => _zoomBy(-1),
                          ),
                        ),
                        _buildSheet(
                          recent,
                          peopleError: userSnap.hasError,
                          loading:
                              postSnap.connectionState ==
                                  ConnectionState.waiting &&
                              !postSnap.hasData,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap(
    List<CommunityPost> posts,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  ) {
    if (_mapTilerKey.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Map disabled: set MAPTILER_KEY with --dart-define to load tiles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeTone.muted),
          ),
        ),
      );
    }
    final here = widget.currentLocation;
    final show = _filter;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(initialCenter: _center, initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: _satellite
              ? 'https://api.maptiler.com/maps/hybrid/{z}/{x}/{y}.jpg?key={key}'
              : 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}',
          additionalOptions: const {'key': _mapTilerKey},
          userAgentPackageName: 'com.example.community',
        ),
        if (here != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: here,
                radius: _nearbyRadiusKm * 1000,
                useRadiusInMeter: true,
                color: const Color(0xFF3B82F6).withValues(alpha: .1),
                borderColor: const Color(0xFF3B82F6).withValues(alpha: .35),
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (show == _MapFilter.all || show == _MapFilter.police)
              ..._policeMarkers(),
            if (show == _MapFilter.all || show == _MapFilter.people)
              ..._peopleMarkers(users),
            if (show == _MapFilter.all ||
                show == _MapFilter.reports ||
                show == _MapFilter.urgent)
              ..._reportMarkers(posts),
            if (here != null)
              Marker(
                point: here,
                width: 64,
                height: 58,
                alignment: const Alignment(0, -.34),
                child: const _YouPin(),
              ),
          ],
        ),
        Scalebar(
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.fromLTRB(14, 14, 0, 0),
          textStyle: const TextStyle(
            color: HomeTone.ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          lineColor: HomeTone.ink,
          strokeWidth: 1.5,
        ),
      ],
    );
  }

  Widget _buildSheet(
    List<CommunityPost> recent, {
    required bool peopleError,
    required bool loading,
  }) {
    final here = widget.currentLocation;
    final scope = here == null
        ? 'Whole community'
        : 'Within ${AreaPulseCard.radiusLabel()}';
    final shown = recent.take(10).toList();

    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: _sheetStart,
      minChildSize: _sheetMin,
      maxChildSize: .9,
      snap: true,
      snapSizes: const [_sheetStart],
      builder: (context, scroll) => DecoratedBox(
        decoration: BoxDecoration(
          color: HomeTone.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E1240).withValues(alpha: .12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            MediaQuery.paddingOf(context).bottom + 16,
          ),
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
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: HomeTone.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$scope • Last 24 hours',
                          style: const TextStyle(
                            color: HomeTone.muted,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ReportCountHeadline(
                          recent: recent,
                          fontSize: 18,
                          oneLine: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AreaStatusPill(recent: recent),
                    ],
                  ),
                ],
              ),
            ),
            if (peopleError) ...[
              const SizedBox(height: 10),
              const Text(
                'Could not load neighbours right now.',
                style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: HomeTone.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HomeTone.border),
                boxShadow: HomeTone.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 6, 2),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Recent reports nearby',
                            style: TextStyle(
                              color: HomeTone.ink,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onOpenBulletin,
                          style: TextButton.styleFrom(
                            foregroundColor: HomeTone.violet,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('See all', style: TextStyle(fontSize: 13.5)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: SkeletonBox(height: 56, color: HomeTone.skeleton),
                    )
                  else if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 6, 18, 20),
                      child: Text(
                        'No reports in the last 24 hours. All quiet nearby.',
                        style: TextStyle(color: HomeTone.muted, fontSize: 13.5),
                      ),
                    )
                  else ...[
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 30,
                          endIndent: 16,
                          color: HomeTone.border,
                        ),
                      _reportRow(shown[i], here),
                    ],
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportRow(CommunityPost post, LatLng? here) {
    final point = _pointOf(post);
    return ReportRow(
      post: post,
      subtitle: [
        if (here != null && point != null)
          distanceLabel(_distanceKm(here, point)),
        timeAgo(post.createdAt),
      ].join('  •  '),
      trailing: const Icon(Icons.chevron_right_rounded, color: HomeTone.muted),
      onTap: () {
        if (point != null) _focus(point);
        _showPost(post);
      },
    );
  }
}

// ------------------------------------------------------------------ widgets

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});
  final _MapFilter selected;
  final ValueChanged<_MapFilter> onSelect;

  static const _chips = [
    (_MapFilter.all, 'All', null, null),
    (_MapFilter.urgent, 'Urgent', Icons.warning_rounded, HomeTone.red),
    (_MapFilter.reports, 'Reports', Icons.campaign_rounded, HomeTone.violet),
    (_MapFilter.people, 'People', Icons.groups_rounded, HomeTone.violet),
    (_MapFilter.police, 'Police', Icons.shield_rounded, HomeTone.blue),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        itemCount: _chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label, icon, iconColor) = _chips[index];
          final isSelected = filter == selected;
          return Semantics(
            selected: isSelected,
            button: true,
            child: Material(
              color: isSelected ? HomeTone.violet : HomeTone.card,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected ? HomeTone.violet : HomeTone.border,
                ),
              ),
              elevation: isSelected ? 2 : 0,
              shadowColor: HomeTone.violet.withValues(alpha: .4),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelect(filter),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: icon == null ? 22 : 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 19,
                          color: isSelected ? Colors.white : iconColor,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : HomeTone.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.satellite,
    required this.canRecenter,
    required this.onRecenter,
    required this.onToggleLayer,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool satellite;
  final bool canRecenter;
  final VoidCallback onRecenter;
  final VoidCallback onToggleLayer;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  Widget _card(Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1E1240).withValues(alpha: .12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );

  Widget _button(IconData icon, String tooltip, VoidCallback? onTap) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
        color: HomeTone.ink,
        disabledColor: HomeTone.muted.withValues(alpha: .4),
        iconSize: 24,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _card(
        _button(
          Icons.my_location_rounded,
          'Centre on me',
          canRecenter ? onRecenter : null,
        ),
      ),
      const SizedBox(height: 10),
      _card(
        _button(
          satellite ? Icons.map_outlined : Icons.layers_outlined,
          satellite ? 'Street map' : 'Satellite view',
          onToggleLayer,
        ),
      ),
      const SizedBox(height: 10),
      _card(
        Column(
          children: [
            _button(Icons.add_rounded, 'Zoom in', onZoomIn),
            Container(width: 26, height: 1, color: HomeTone.border),
            _button(Icons.remove_rounded, 'Zoom out', onZoomOut),
          ],
        ),
      ),
    ],
  );
}

/// Coloured round marker with a white ring; urgent ones get a soft glow.
class _RoundPin extends StatelessWidget {
  const _RoundPin({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.glow = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final pin = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 21),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: glow
              ? Container(
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
                  child: pin,
                )
              : pin,
        ),
      ),
    );
  }
}

/// Avatar pin for a neighbour, with a green dot when they are online.
class _PersonPin extends StatelessWidget {
  const _PersonPin({
    required this.name,
    required this.color,
    required this.online,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$name${online ? ', online' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: color,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                      ),
                    ),
                  ),
                ),
                if (online)
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            CustomPaint(size: const Size(14, 9), painter: _PointerPainter()),
          ],
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Blue dot for the user's own position, labelled "You".
class _YouPin extends StatelessWidget {
  const _YouPin();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your location',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: HomeTone.violet,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'You',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: .45),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
