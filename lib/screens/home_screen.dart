import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:community/screens/report_incident_screen.dart';
import 'package:community/screens/around_screen.dart';
import 'package:community/screens/chat_list_screen.dart';
import 'package:community/repositories/chat_repository.dart';
import 'package:community/screens/community_bulletin_screen.dart';
import 'package:community/screens/more_info_screen.dart';
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
import '../widgets/community_ui.dart';
import '../widgets/home_overview.dart';

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

  void _showMoreInfo() {
    _openScreen(
      MoreInfoScreen(
        authService: widget.authService,
        postRepository: widget.postRepository,
        currentLocation: _currentLocation,
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

  void _openBulletin() => _openScreen(
    CommunityBulletinScreen(
      authService: widget.authService,
      postRepository: widget.postRepository,
    ),
  );

  void _openMessages() => _openScreen(
    ChatListScreen(
      authService: widget.authService,
      chatRepository: _chatRepository,
    ),
  );

  void _openReport() => _openScreen(
    ReportIncidentScreen(
      authService: widget.authService,
      postRepository: widget.postRepository,
      initialLocation: _currentLocation,
    ),
  );

  String _search = '';

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final displayName = user?.displayName;
    final firstName = (displayName == null || displayName.trim().isEmpty)
        ? (user?.email?.split('@').first ?? 'neighbor')
        : displayName.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        title: const Row(
          children: [
            IconBadge(icon: Icons.hub_outlined, size: 38),
            SizedBox(width: 10),
            Text(
              'Community',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bulletin board',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: _openBulletin,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const CircleAvatar(
              backgroundColor: AppColors.safeDim,
              child: Icon(Icons.person_outline, color: AppColors.safe),
            ),
            onPressed: () =>
                _openScreen(SettingsScreen(authService: widget.authService)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,

        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              _openAroundScreen();
              break;
            case 2:
              _openReport();
              break;
            case 3:
              _openMessages();
              break;
            case 4:
              _openScreen(SettingsScreen(authService: widget.authService));
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded, color: AppColors.safe),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            label: 'Around',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_alert_outlined),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: widget.postRepository.getPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasData) _allPosts = snapshot.data!;
          final posts = _allPosts
              .where(
                (post) =>
                    '${post.content} ${post.authorName} ${post.category.name}'
                        .toLowerCase()
                        .contains(_search.toLowerCase()),
              )
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  HomeOverview(
                    greeting: '$_greeting, $firstName',
                    onAround: _openAroundScreen,
                    onSos: _showSosDialog,
                    onReport: _openReport,
                    onVacation: () => _openScreen(
                      VacationWatchScreen(authService: widget.authService),
                    ),
                    onMessages: _openMessages,
                    onBulletin: _openBulletin,
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nearby map',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (_locationError != null && !_isLoadingLocation)
                        TextButton(
                          onPressed: _loadCurrentLocation,
                          child: const Text('Retry'),
                        ),
                      TextButton.icon(
                        onPressed: _openAroundScreen,
                        icon: const Icon(Icons.near_me_outlined, size: 17),
                        label: const Text('Around'),
                      ),
                    ],
                  ),
                  _MapSection(
                    center: _currentLocation ?? _defaultCenter,
                    currentLocation: _currentLocation,
                    isLoadingLocation: _isLoadingLocation,
                    locationError: _locationError,
                    posts: _allPosts,
                  ),
                  const SizedBox(height: 26),
                  const SectionHeading(
                    title: 'Safety tools',
                    subtitle: 'Looking out for each other.',
                  ),
                  _QuickActionsGrid(
                    onVacationWatch: () => _openScreen(
                      VacationWatchScreen(authService: widget.authService),
                    ),
                    onDirectory: () =>
                        _openScreen(const NeighborDirectoryScreen()),
                    onEmergencyContacts: () => _openScreen(
                      EmergencyContactsScreen(onSos: _showSosDialog),
                    ),
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, color: AppColors.safe),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Community updates',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _openBulletin,
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (value) =>
                        setState(() => _search = value.trim()),
                    decoration: const InputDecoration(
                      hintText: 'Search community updates',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _allPosts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError && _allPosts.isEmpty)
                    const _EmptyState(
                      icon: Icons.wifi_off,
                      message: 'Unable to load updates right now.',
                    )
                  else if (posts.isEmpty)
                    _EmptyState(
                      icon: Icons.forum_outlined,
                      message: _search.isEmpty
                          ? 'No updates yet. Be the first to post.'
                          : 'No updates match your search.',
                    )
                  else
                    ...posts
                        .take(_search.isEmpty ? 5 : posts.length)
                        .map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PostCard(
                              post: post,
                              authService: widget.authService,
                              postRepository: widget.postRepository,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          );
        },
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 3 : 2;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var index = 0; index < actions.length; index++)
              SizedBox(
                width: width,
                child: Reveal(
                  order: index,
                  child: Material(
                    color: AppColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: actions[index].onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 18,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              actions[index].icon,
                              color: AppColors.watch,
                              size: 21,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                actions[index].label.replaceAll('\n', ' '),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
        height: 250,
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
        child: SizedBox(
          height: 250,
          child: Stack(
            children: [
              FlutterMap(
                key: ValueKey(currentLocation == null),
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
                  if (currentLocation != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: currentLocation!,
                          radius: 250,
                          useRadiusInMeter: true,
                          color: AppColors.watch.withValues(alpha: 0.08),
                          borderColor: AppColors.watch.withValues(alpha: 0.5),
                          borderStrokeWidth: 2,
                        ),
                      ],
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
