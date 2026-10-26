import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:community/screens/report_incident_screen.dart';
import 'package:community/screens/around_screen.dart';
import 'package:community/screens/chat_list_screen.dart';
import 'package:community/repositories/chat_repository.dart';
import 'package:community/screens/community_bulletin_screen.dart';
import 'package:community/screens/more_info_screen.dart';
import 'package:community/screens/settings_screen.dart';
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

/// Signed-in shell: bottom tabs for Home, Map, Messages and Me, with Report
/// as a raised action in the middle that opens the report form.
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

enum _Tab { home, map, report, messages, me }

class _HomeScreenState extends State<HomeScreen> {
  static const LatLng _defaultCenter = LatLng(0.3476, 32.5825);
  final ChatRepository _chatRepository = ChatRepository();
  final UserLocationTrackingService _locationTrackingService =
      UserLocationTrackingService();

  LatLng? _currentLocation;
  String? _locationError;
  bool _isLoadingLocation = true;

  _Tab _tab = _Tab.home;
  // Tabs are built the first time they are opened, then kept alive.
  final Set<_Tab> _visited = {_Tab.home};

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

  Future<T?> _openScreen<T>(Widget screen) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _selectTab(_Tab tab) {
    if (tab == _Tab.report) {
      _openReport();
      return;
    }
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Future<void> _confirmSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.sos_rounded, color: AppColors.alert, size: 36),
        title: const Text('Send SOS alert?'),
        content: const Text(
          'This posts an urgent alert with your location to the community '
          'feed. Only use it if you are in immediate danger. For police, '
          'call 999.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.alert,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _sendSos();
  }

  Future<void> _sendSos() async {
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
      SnackBar(
        backgroundColor: AppColors.alert,
        content: const Text('SOS posted. Neighbours can see it in the feed.'),
      ),
    );
  }

  void _openBulletin() => _openScreen(
    CommunityBulletinScreen(
      authService: widget.authService,
      postRepository: widget.postRepository,
    ),
  );

  void _openReport() => _openScreen(
    ReportIncidentScreen(
      authService: widget.authService,
      postRepository: widget.postRepository,
      initialLocation: _currentLocation,
    ),
  );

  List<SettingsTool> get _tools => [
    SettingsTool(
      icon: Icons.cottage_outlined,
      title: 'Vacation watch',
      subtitle: 'Neighbours keep an eye on your home',
      onTap: () =>
          _openScreen(VacationWatchScreen(authService: widget.authService)),
    ),
    SettingsTool(
      icon: Icons.campaign_outlined,
      title: 'Community bulletin',
      subtitle: 'All updates and announcements',
      onTap: _openBulletin,
    ),
    SettingsTool(
      icon: Icons.groups_outlined,
      title: 'Neighbour directory',
      subtitle: 'Members and verified neighbours',
      onTap: () => _openScreen(const NeighborDirectoryScreen()),
    ),
    SettingsTool(
      icon: Icons.edit_note_outlined,
      title: 'My safety log',
      subtitle: 'Incidents you have reported',
      onTap: () => _openScreen(
        SafetyLogScreen(
          authService: widget.authService,
          postRepository: widget.postRepository,
        ),
      ),
    ),
    SettingsTool(
      icon: Icons.bar_chart_rounded,
      title: 'Crime stats',
      subtitle: 'Trends in your neighbourhood',
      onTap: () => _openScreen(
        StatisticsDashboardScreen(postRepository: widget.postRepository),
      ),
    ),
    SettingsTool(
      icon: Icons.info_outline_rounded,
      title: 'About & guidelines',
      subtitle: 'How Community works',
      onTap: () => _openScreen(
        MoreInfoScreen(
          authService: widget.authService,
          postRepository: widget.postRepository,
          currentLocation: _currentLocation,
        ),
      ),
    ),
  ];

  Widget _buildTab(_Tab tab) {
    if (!_visited.contains(tab)) return const SizedBox.shrink();
    switch (tab) {
      case _Tab.home:
        return _HomeTab(
          authService: widget.authService,
          postRepository: widget.postRepository,
          currentLocation: _currentLocation,
          isLoadingLocation: _isLoadingLocation,
          locationError: _locationError,
          onRetryLocation: _loadCurrentLocation,
          onSosTap: _confirmSos,
          onSosTriggered: _sendSos,
          onReport: _openReport,
          onOpenBulletin: _openBulletin,
          onOpenMap: () => _selectTab(_Tab.map),
          onOpenMe: () => _selectTab(_Tab.me),
          onVacation: () =>
              _openScreen(VacationWatchScreen(authService: widget.authService)),
          onEmergency: () =>
              _openScreen(EmergencyContactsScreen(onSos: _confirmSos)),
          onPolice: () => _openScreen(
            PoliceStationLocatorScreen(userLocation: _currentLocation),
          ),
        );
      case _Tab.map:
        return AroundScreen(
          key: ValueKey(_currentLocation == null),
          currentUserId: widget.authService.currentUser?.uid ?? '',
          initialCenter: _currentLocation ?? _defaultCenter,
        );
      case _Tab.messages:
        return ChatListScreen(
          authService: widget.authService,
          chatRepository: _chatRepository,
        );
      case _Tab.me:
        return SettingsScreen(authService: widget.authService, tools: _tools);
      case _Tab.report:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [_Tab.home, _Tab.map, _Tab.messages, _Tab.me];
    return PopScope(
      canPop: _tab == _Tab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(_Tab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: tabs.indexOf(_tab),
          children: [for (final tab in tabs) _buildTab(tab)],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (index) => _selectTab(_Tab.values[index]),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Container(
                width: 46,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.add_rounded, color: AppColors.onPrimary),
              ),
              label: 'Report',
            ),
            const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Messages',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.authService,
    required this.postRepository,
    required this.currentLocation,
    required this.isLoadingLocation,
    required this.locationError,
    required this.onRetryLocation,
    required this.onSosTap,
    required this.onSosTriggered,
    required this.onReport,
    required this.onOpenBulletin,
    required this.onOpenMap,
    required this.onOpenMe,
    required this.onVacation,
    required this.onEmergency,
    required this.onPolice,
  });

  final AuthService authService;
  final PostRepository postRepository;
  final LatLng? currentLocation;
  final bool isLoadingLocation;
  final String? locationError;
  final VoidCallback onRetryLocation;
  final VoidCallback onSosTap;
  final VoidCallback onSosTriggered;
  final VoidCallback onReport;
  final VoidCallback onOpenBulletin;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenMe;
  final VoidCallback onVacation;
  final VoidCallback onEmergency;
  final VoidCallback onPolice;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _firstName() {
    final user = authService.currentUser;
    final displayName = user?.displayName;
    if (displayName == null || displayName.trim().isEmpty) {
      return user?.email?.split('@').first ?? 'neighbour';
    }
    return displayName.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final name = _firstName();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Row(
          children: [
            Semantics(
              button: true,
              label: 'Open profile',
              child: InkWell(
                onTap: onOpenMe,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 21,
                  backgroundColor: AppColors.watchDim,
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting, style: textTheme.bodySmall),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(fontSize: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Community bulletin',
            onPressed: onOpenBulletin,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: postRepository.getPostsStream(),
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const <CommunityPost>[];
          final loading =
              snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  HomeOverview(
                    posts: posts,
                    currentLocation: currentLocation,
                    onSosTap: onSosTap,
                    onSosTriggered: onSosTriggered,
                    onReport: onReport,
                    onVacation: onVacation,
                    onEmergency: onEmergency,
                    onPolice: onPolice,
                    onOpenMap: onOpenMap,
                  ),
                  if (!isLoadingLocation && locationError != null)
                    _LocationNotice(
                      message: locationError!,
                      onRetry: onRetryLocation,
                    ),
                  const SizedBox(height: 24),
                  SectionHeading(
                    title: 'Updates near you',
                    action: TextButton(
                      onPressed: onOpenBulletin,
                      child: const Text('See all'),
                    ),
                  ),
                  if (loading)
                    for (var i = 0; i < 3; i++)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: SkeletonBox(height: 72, radius: 16),
                      )
                  else if (snapshot.hasError && posts.isEmpty)
                    const _EmptyState(
                      icon: Icons.wifi_off_rounded,
                      message: 'Could not load updates. Check your connection.',
                    )
                  else if (posts.isEmpty)
                    _EmptyState(
                      icon: Icons.forum_outlined,
                      message: 'No updates yet.',
                      action: TextButton(
                        onPressed: onReport,
                        child: const Text('Report something'),
                      ),
                    )
                  else
                    for (final post in posts.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _UpdateRow(post: post, onTap: onOpenBulletin),
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

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_outlined, size: 18, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _UpdateRow extends StatelessWidget {
  const _UpdateRow({required this.post, required this.onTap});
  final CommunityPost post;
  final VoidCallback onTap;

  String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final color = severityColor(post.severity);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          categoryIcon(post.category),
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${post.severity.label} · ${post.category.label}'
                              ' · ${_ago(post.createdAt)}',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
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
          ?action,
        ],
      ),
    );
  }
}
