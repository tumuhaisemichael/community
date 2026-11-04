import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' show LatLng;
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
import '../services/ui_preferences.dart';
import '../services/user_location_tracking_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_tone.dart';
import '../widgets/community_ui.dart';
import '../widgets/glass_nav_bar.dart';
import '../widgets/hero_header.dart';
import '../widgets/overlap_header.dart';
import '../widgets/report_row.dart';
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

  /// Where the Report button sits on the bar (0 = far left, 4 = far right).
  int _reportSlot = 2;
  // Tabs are built the first time they are opened, then kept alive.
  final Set<_Tab> _visited = {_Tab.home};

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _loadReportSlot();
    UiPreferences.instance.load(widget.authService.currentUser?.uid).then((_) {
      // Open on the tab chosen in Me → Home Screen, unless the user has
      // already moved somewhere.
      if (!mounted || _tab != _Tab.home) return;
      final start = switch (UiPreferences.instance.startTab) {
        'map' => _Tab.map,
        'messages' => _Tab.messages,
        _ => _Tab.home,
      };
      if (start != _Tab.home) _selectTab(start);
    });
  }

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final userId = widget.authService.currentUser?.uid;
    if (userId == null || userId.isEmpty) return null;
    return FirebaseFirestore.instance.collection('users').doc(userId);
  }

  Future<void> _loadReportSlot() async {
    try {
      final snapshot = await _userDoc?.get();
      final slot = snapshot?.data()?['navReportSlot'];
      if (!mounted || slot is! int) return;
      setState(() => _reportSlot = slot.clamp(0, _navItems.length));
    } catch (_) {
      // Keep the default position if the saved one cannot be read.
    }
  }

  void _moveReportButton(int slot) {
    setState(() => _reportSlot = slot);
    _userDoc
        ?.set({'navReportSlot': slot}, SetOptions(merge: true))
        .catchError((_) {});
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

  String get _userInitial {
    final user = widget.authService.currentUser;
    final name = user?.displayName?.trim();
    final source = name == null || name.isEmpty ? (user?.email ?? '') : name;
    return source.isEmpty ? '?' : source[0].toUpperCase();
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
      currentLocation: _currentLocation,
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
      onTap: () => _openScreen(
        NeighborDirectoryScreen(
          authService: widget.authService,
          chatRepository: _chatRepository,
        ),
      ),
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
          currentLocation: _currentLocation,
          fallbackCenter: _defaultCenter,
          postRepository: widget.postRepository,
          userInitial: _userInitial,
          onOpenBulletin: _openBulletin,
          onOpenMe: () => _selectTab(_Tab.me),
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

  static const _navTabs = [_Tab.home, _Tab.map, _Tab.messages, _Tab.me];
  static const _navItems = [
    GlassNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    GlassNavItem(
      icon: Icons.location_on_outlined,
      selectedIcon: Icons.location_on_rounded,
      label: 'Map',
    ),
    GlassNavItem(
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      label: 'Messages',
    ),
    GlassNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Me',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isHome = _tab == _Tab.home;
    return PopScope(
      canPop: isHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(_Tab.home);
      },
      child: Scaffold(
        // Every tab uses the light violet look and runs all the way down
        // behind the glass bar, so nothing dark shows around it.
        extendBody: true,
        backgroundColor: HomeTone.canvas,
        body: IndexedStack(
          index: _navTabs.indexOf(_tab),
          children: [for (final tab in _navTabs) _buildTab(tab)],
        ),
        bottomNavigationBar: GlassNavBar(
          items: _navItems,
          selectedIndex: _navTabs.indexOf(_tab),
          onSelect: (index) => _selectTab(_navTabs[index]),
          actionSlot: _reportSlot,
          onAction: _openReport,
          onActionMoved: _moveReportButton,
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: StreamBuilder<List<CommunityPost>>(
        stream: postRepository.getPostsStream(),
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const <CommunityPost>[];
          final loading =
              snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData;
          final hasAlerts = recentNearby(
            posts,
            currentLocation,
          ).any((p) => p.severity.isSerious);

          return ListView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              OverlapHeader(
                overlap: 28,
                header: HeroHeader(
                  title: '$_greeting, $name 👋',
                  subtitle: 'Your neighbourhood at a glance',
                  initial: name.isEmpty ? '?' : name[0].toUpperCase(),
                  hasAlerts: hasAlerts,
                  onOpenBulletin: onOpenBulletin,
                  onOpenMe: onOpenMe,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: HomeTone.canvas,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: LocationNotice(
                                  message: locationError!,
                                  onRetry: onRetryLocation,
                                ),
                              ),
                            const SizedBox(height: 14),
                            Reveal(
                              order: 3,
                              child: _UpdatesCard(
                                posts: posts,
                                loading: loading,
                                hasError: snapshot.hasError,
                                onOpenBulletin: onOpenBulletin,
                                onReport: onReport,
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
      ),
    );
  }
}

/// "Updates near you": the five newest posts in one card.
class _UpdatesCard extends StatelessWidget {
  const _UpdatesCard({
    required this.posts,
    required this.loading,
    required this.hasError,
    required this.onOpenBulletin,
    required this.onReport,
  });

  final List<CommunityPost> posts;
  final bool loading;
  final bool hasError;
  final VoidCallback onOpenBulletin;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final shown = posts.take(5).toList();
    return Container(
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
            padding: const EdgeInsets.fromLTRB(18, 10, 6, 4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Updates near you',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: HomeTone.ink,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenBulletin,
                  style: TextButton.styleFrom(foregroundColor: HomeTone.violet),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('See all', style: TextStyle(fontSize: 14.5)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  for (var i = 0; i < 3; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: SkeletonBox(
                        height: 56,
                        radius: 12,
                        color: HomeTone.skeleton,
                      ),
                    ),
                ],
              ),
            )
          else if (hasError && posts.isEmpty)
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
                style: TextButton.styleFrom(foregroundColor: HomeTone.violet),
                child: const Text('Report something'),
              ),
            )
          else ...[
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 30,
                  endIndent: 16,
                  color: HomeTone.border,
                ),
              ReportRow(
                post: shown[i],
                subtitle:
                    '${shown[i].categoriesLabel} · ${shown[i].severity.label}',
                trailing: Text(
                  timeAgo(shown[i].createdAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: HomeTone.muted),
                ),
                onTap: onOpenBulletin,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Icon(icon, color: HomeTone.muted, size: 28),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: HomeTone.muted),
          ),
          ?action,
        ],
      ),
    );
  }
}
