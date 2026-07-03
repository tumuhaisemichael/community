import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:community/screens/report_incident_screen.dart';
import 'package:community/screens/around_screen.dart';
import 'package:community/screens/chat_list_screen.dart';
import 'package:community/repositories/chat_repository.dart';
import 'package:community/screens/community_bulletin_screen.dart';
import 'package:community/screens/settings_screen.dart';
import 'package:community/widgets/post_card.dart';
import 'package:community/screens/vacation_watch_screen.dart';
import 'package:community/screens/neighbor_directory_screen.dart';
import 'package:community/screens/emergency_contacts_screen.dart';
import 'package:community/screens/police_locator_screen.dart';
import 'package:community/screens/safety_log_screen.dart';
import 'package:community/screens/statistics_dashboard_screen.dart';

import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import '../services/user_location_tracking_service.dart';
import '../theme/app_theme.dart';
import '../widgets/beacon_mark.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.postRepository,
  });

  final AuthService authService;
  final PostRepository postRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const LatLng _defaultCenter = LatLng(0.3476, 32.5825);
  final ChatRepository _chatRepository = ChatRepository();
  final UserLocationTrackingService _locationTrackingService =
      UserLocationTrackingService();

  LatLng? _currentLocation;
  String? _locationError;
  bool _isLoadingLocation = true;
  List<CommunityPost> _allPosts = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _locationTrackingService.stopTracking();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    final userId = widget.authService.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      _setLocationError('Sign in to share your location.');
      return;
    }

    await _locationTrackingService.startTracking(
      userId: userId,
      onLocation: (location) {
        if (!mounted) return;
        setState(() {
          _currentLocation = location;
          _locationError = null;
          _isLoadingLocation = false;
        });
      },
      onError: _setLocationError,
    );
  }

  void _setLocationError(String message) {
    if (!mounted) return;
    setState(() {
      _locationError = message;
      _isLoadingLocation = false;
    });
  }

  Future<void> _openAroundScreen() {
    final userId = widget.authService.currentUser?.uid ?? '';
    return _openScreen(
      AroundScreen(
        currentUserId: userId,
        initialCenter: _currentLocation ?? _defaultCenter,
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<T?> _openScreen<T>(Widget screen) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showInfoSheet(String title, String content) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(content, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  void _showMoreInfo() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.watch),
                title: const Text('About Community'),
                onTap: () {
                  Navigator.pop(context);
                  _showInfoSheet(
                    'About Community',
                    'Community is a space for neighbors and members to share updates, '
                        'learn from each other, and build local connections.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.rule_outlined,
                  color: AppColors.watch,
                ),
                title: const Text('Community Guidelines'),
                onTap: () {
                  Navigator.pop(context);
                  _showInfoSheet(
                    'Community Guidelines',
                    'Be respectful, avoid harmful language, protect personal privacy, '
                        'and keep discussions helpful and inclusive for everyone.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline, color: AppColors.watch),
                title: const Text('Help'),
                onTap: () {
                  Navigator.pop(context);
                  _showInfoSheet(
                    'Help',
                    'Need support? For now, contact the app owner or team directly '
                        'while we prepare in-app support and reporting tools.',
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSosDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send SOS alert?'),
        content: const Text(
          'This will send an instant alert with your location to all nearby '
          'community members. Only use this if you are in immediate danger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = widget.authService.currentUser;
    final authorName = user?.displayName ?? user?.email ?? 'Member';
    final panicPost = CommunityPost(
      id: '',
      authorName: authorName,
      authorId: user?.uid ?? '',
      content: '🚨 SOS PANIC ALERT: I NEED IMMEDIATE HELP!',
      createdAt: DateTime.now(),
      likes: 0,
      category: PostCategory.medical,
      severity: PostSeverity.critical,
      latitude: _currentLocation?.latitude,
      longitude: _currentLocation?.longitude,
    );
    await widget.postRepository.addPost(panicPost);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.alert,
        content: Text('SOS sent. Nearby neighbors have been notified.'),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final displayName = user?.displayName;
    final firstName = (displayName == null || displayName.trim().isEmpty)
        ? (user?.email?.split('@').first ?? 'neighbor')
        : displayName.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            BeaconMark(size: 26),
            SizedBox(width: 10),
            Text('Community'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bulletin board',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => _openScreen(
              CommunityBulletinScreen(
                authService: widget.authService,
                postRepository: widget.postRepository,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => _openScreen(
              ChatListScreen(
                authService: widget.authService,
                chatRepository: _chatRepository,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                _openScreen(SettingsScreen(authService: widget.authService)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openScreen(
          ReportIncidentScreen(
            authService: widget.authService,
            postRepository: widget.postRepository,
            initialLocation: _currentLocation,
          ),
        ).then((_) => setState(() {})),
        label: const Text('Report'),
        icon: const Icon(Icons.add_alert_outlined),
        backgroundColor: AppColors.ink,
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: widget.postRepository.getPostsStream(),
        builder: (context, snapshot) {
          final isInitialLoading =
              snapshot.connectionState == ConnectionState.waiting &&
              _allPosts.isEmpty;
          if (snapshot.hasData) {
            _allPosts = snapshot.data!;
          }

          final latestPosts = _allPosts.take(5).toList();
          final updatesPaneHeight = math.max(
            220.0,
            math.min(560.0, latestPosts.length * 185.0),
          );

          final feedKey = snapshot.hasError && _allPosts.isEmpty
              ? 'error'
              : _allPosts.isEmpty
              ? 'empty'
              : _allPosts.map((p) => p.id).join(',');

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: isInitialLoading
                ? const Center(
                    key: ValueKey('loading'),
                    child: CircularProgressIndicator(color: AppColors.ink),
                  )
                : ListView(
                    key: const ValueKey('content'),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: [
                      _Stagger(
                        index: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_greeting, $firstName',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your neighborhood at a glance.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Stagger(
                        index: 1,
                        child: _SosCard(onPressed: _showSosDialog),
                      ),
                      const SizedBox(height: 24),
                      _Stagger(
                        index: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Safety tools',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _QuickActionsGrid(
                              onVacationWatch: () => _openScreen(
                                VacationWatchScreen(
                                  authService: widget.authService,
                                ),
                              ),
                              onDirectory: () =>
                                  _openScreen(const NeighborDirectoryScreen()),
                              onEmergencyContacts: () =>
                                  _openScreen(const EmergencyContactsScreen()),
                              onPoliceLocator: () => _openScreen(
                                PoliceStationLocatorScreen(
                                  userLocation: _currentLocation,
                                ),
                              ),
                              onSafetyLog: () => _openScreen(
                                SafetyLogScreen(
                                  authService: widget.authService,
                                  postRepository: widget.postRepository,
                                ),
                              ),
                              onStats: () => _openScreen(
                                StatisticsDashboardScreen(
                                  postRepository: widget.postRepository,
                                ),
                              ),
                              onMoreInfo: _showMoreInfo,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _Stagger(
                        index: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Nearby map',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: _openAroundScreen,
                                      child: const Text('Around'),
                                    ),
                                    if (_locationError != null &&
                                        !_isLoadingLocation)
                                      TextButton(
                                        onPressed: _loadCurrentLocation,
                                        child: const Text('Retry'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _MapSection(
                              center: _currentLocation ?? _defaultCenter,
                              currentLocation: _currentLocation,
                              isLoadingLocation: _isLoadingLocation,
                              locationError: _locationError,
                              posts: _allPosts,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _Stagger(
                        index: 4,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Community updates',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'View all updates',
                              onPressed: () => _openScreen(
                                CommunityBulletinScreen(
                                  authService: widget.authService,
                                  postRepository: widget.postRepository,
                                ),
                              ),
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        child: KeyedSubtree(
                          key: ValueKey(feedKey),
                          child: Column(
                            children: [
                              if (snapshot.hasError && _allPosts.isEmpty)
                                const _EmptyState(
                                  icon: Icons.wifi_off,
                                  message: 'Unable to load updates right now.',
                                )
                              else if (_allPosts.isEmpty)
                                const _EmptyState(
                                  icon: Icons.forum_outlined,
                                  message:
                                      'No updates yet. Be the first to post.',
                                )
                              else
                                SizedBox(
                                  height: updatesPaneHeight,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: latestPosts.length,
                                    itemBuilder: (context, index) {
                                      final post = latestPosts[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: PostCard(
                                          post: post,
                                          authService: widget.authService,
                                          postRepository: widget.postRepository,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _Stagger extends StatelessWidget {
  const _Stagger({required this.index, required this.child, this.duration});

  final int index;
  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration ?? const Duration(milliseconds: 560),
      curve: Interval(
        (index * 0.09).clamp(0.0, 0.6),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _SosCard extends StatefulWidget {
  const _SosCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_SosCard> createState() => _SosCardState();
}

class _SosCardState extends State<_SosCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: AnimatedScale(
              scale: _pressed ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              child: SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const BeaconMark(
                      size: 76,
                      color: AppColors.alert,
                      animate: true,
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.alert,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In immediate danger?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap the beacon to alert nearby neighbors with your location.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onVacationWatch,
    required this.onDirectory,
    required this.onEmergencyContacts,
    required this.onPoliceLocator,
    required this.onSafetyLog,
    required this.onStats,
    required this.onMoreInfo,
  });

  final VoidCallback onVacationWatch;
  final VoidCallback onDirectory;
  final VoidCallback onEmergencyContacts;
  final VoidCallback onPoliceLocator;
  final VoidCallback onSafetyLog;
  final VoidCallback onStats;
  final VoidCallback onMoreInfo;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.beach_access_outlined,
        label: 'Vacation\nwatch',
        onTap: onVacationWatch,
      ),
      (
        icon: Icons.groups_outlined,
        label: 'Neighbor\ndirectory',
        onTap: onDirectory,
      ),
      (
        icon: Icons.phone_in_talk_outlined,
        label: 'Emergency\ncontacts',
        onTap: onEmergencyContacts,
      ),
      (
        icon: Icons.local_police_outlined,
        label: 'Find\npolice',
        onTap: onPoliceLocator,
      ),
      (
        icon: Icons.edit_note_outlined,
        label: 'Safety\nlog',
        onTap: onSafetyLog,
      ),
      (icon: Icons.bar_chart_outlined, label: 'Crime\nstats', onTap: onStats),
      (icon: Icons.more_horiz, label: 'More\ninfo', onTap: onMoreInfo),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return _Stagger(
          index: index,
          duration: const Duration(milliseconds: 420),
          child: Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: action.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action.icon, color: AppColors.watch, size: 22),
                    const SizedBox(height: 8),
                    Text(
                      action.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.mutedText, size: 28),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  const _MapSection({
    required this.center,
    required this.currentLocation,
    required this.isLoadingLocation,
    required this.locationError,
    required this.posts,
  });

  final LatLng center;
  final LatLng? currentLocation;
  final bool isLoadingLocation;
  final String? locationError;
  final List<CommunityPost> posts;

  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'uWW7vmIm5gtAhwbF20VH',
  );

  Color _markerColor(PostSeverity severity) {
    switch (severity) {
      case PostSeverity.low:
        return AppColors.watch;
      case PostSeverity.medium:
        return const Color(0xFFCB8A1E);
      case PostSeverity.high:
        return AppColors.alert;
      case PostSeverity.critical:
        return const Color(0xFF7B2CBF);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mapTilerKey.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Map disabled: set MAPTILER_KEY with --dart-define to load tiles.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
        child: SizedBox(
          height: 220,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: currentLocation != null ? 16 : 12,
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
                      if (currentLocation != null)
                        Marker(
                          point: currentLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.person_pin_circle,
                            size: 40,
                            color: AppColors.watch,
                          ),
                        ),
                      ...posts
                          .where(
                            (p) => p.latitude != null && p.longitude != null,
                          )
                          .map(
                            (p) => Marker(
                              point: LatLng(p.latitude!, p.longitude!),
                              width: 28,
                              height: 28,
                              child: Icon(
                                p.category == PostCategory.medical
                                    ? Icons.medical_services
                                    : Icons.warning,
                                size: 26,
                                color: _markerColor(p.severity),
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
              if (isLoadingLocation)
                const Align(
                  alignment: Alignment.topCenter,
                  child: _MapBanner(
                    text: 'Fetching your location…',
                    icon: Icons.location_searching,
                  ),
                ),
              if (!isLoadingLocation && locationError != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: _MapBanner(
                    text: locationError!,
                    icon: Icons.location_off,
                    isError: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapBanner extends StatelessWidget {
  const _MapBanner({
    required this.text,
    required this.icon,
    this.isError = false,
  });

  final String text;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isError ? AppColors.alert : AppColors.ink,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isError ? AppColors.alert : AppColors.ink,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
