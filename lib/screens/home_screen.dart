import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:community/screens/report_incident_screen.dart';
import 'package:intl/intl.dart';
import 'package:community/screens/chat_list_screen.dart';
import 'package:community/repositories/chat_repository.dart';
import 'package:community/screens/community_bulletin_screen.dart';
import 'package:community/screens/settings_screen.dart';
import 'package:community/widgets/post_card.dart';
import 'package:community/screens/vacation_watch_screen.dart';

import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';

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

  LatLng? _currentLocation;
  String? _locationError;
  bool _isLoadingLocation = true;
  List<CommunityPost> _allPosts = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocationError('Location services are off. Turn them on to pin your location.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setLocationError('Location permission denied. Enable it to show your pin.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocationError(
          'Location permission is permanently denied. Enable it in settings to show your pin.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _locationError = null;
        _isLoadingLocation = false;
      });
    } catch (_) {
      _setLocationError('Could not fetch location right now. Please try again.');
    }
  }

  void _setLocationError(String message) {
    if (!mounted) return;

    setState(() {
      _locationError = message;
      _isLoadingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = widget.authService.currentUser?.email ?? 'Member';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Home'),
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsScreen(authService: widget.authService),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<_HomeMenuAction>(
            tooltip: 'Menu',
            onSelected: (value) => _showMenuContent(context, value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _HomeMenuAction.about,
                child: Text('About Community'),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.guidelines,
                child: Text('Community Guidelines'),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.vacation,
                child: Text('Vacation Watch'),
              ),
              PopupMenuItem(value: _HomeMenuAction.help, child: Text('Help')),
            ],
          ),
          IconButton(
            tooltip: 'Bulletin Board',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommunityBulletinScreen(
                  authService: widget.authService,
                  postRepository: widget.postRepository,
                ),
              ),
            ),
            icon: const Icon(Icons.campaign_outlined),
          ),
          IconButton(
            tooltip: 'Messages',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatListScreen(
                  authService: widget.authService,
                  chatRepository: _chatRepository,
                ),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.authService.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'panic_button',
            onPressed: () => _showPanicDialog(context),
            backgroundColor: Colors.red,
            child: const Icon(Icons.emergency, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'report_button',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportIncidentScreen(
                  authService: widget.authService,
                  postRepository: widget.postRepository,
                  initialLocation: _currentLocation,
                ),
              ),
            ).then((_) => setState(() {})),
            label: const Text('Report'),
            icon: const Icon(Icons.add_alert),
          ),
        ],
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: widget.postRepository.getPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _allPosts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && _allPosts.isEmpty) {
            return const Center(child: Text('Unable to load posts.'));
          }

          if (snapshot.hasData) {
            _allPosts = snapshot.data!;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Welcome, $userEmail',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Your current location is pinned on the map below.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _MapSection(
                center: _currentLocation ?? _defaultCenter,
                currentLocation: _currentLocation,
                isLoadingLocation: _isLoadingLocation,
                locationError: _locationError,
                onRetry: _loadCurrentLocation,
                posts: _allPosts,
              ),
              const SizedBox(height: 20),
              Text(
                'Here are community updates:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ..._allPosts.map((post) => PostCard(post: post)),
            ],
          );
        },
      ),
    );
  }

  void _showMenuContent(BuildContext context, _HomeMenuAction action) {
    if (action == _HomeMenuAction.vacation) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VacationWatchScreen(authService: widget.authService),
        ),
      );
      return;
    }

    final data = _menuData[action]!;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(data.content, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        );
      },
    );
  }

  void _showPanicDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('EMERGENCY PANIC ALERT'),
        content: const Text(
          'This will send an instant alert with your location to all nearby community members. Are you in immediate danger?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final user = widget.authService.currentUser;
              final authorName = user?.displayName ?? user?.email ?? 'Member';
              final panicPost = CommunityPost(
                id: '',
                authorName: authorName,
                authorId: user?.uid ?? '',
                content: '🚨 SOS PANIC ALERT: I NEED IMMEDIATE HELP!',
                createdAt: DateTime.now(),
                likes: 0,
                category: PostCategory.medical, // Defaulting to medical for panic
                severity: PostSeverity.critical,
                latitude: _currentLocation?.latitude,
                longitude: _currentLocation?.longitude,
              );
              await widget.postRepository.addPost(panicPost);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Panic alert sent to community!'),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() {});
              }
            },
            child: const Text('SEND SOS'),
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
    required this.onRetry,
    required this.posts,
  });

  final LatLng center;
  final LatLng? currentLocation;
  final bool isLoadingLocation;
  final String? locationError;
  final Future<void> Function() onRetry;
  final List<CommunityPost> posts;
  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_KEY',
    defaultValue: 'uWW7vmIm5gtAhwbF20VH',
  );

  @override
  Widget build(BuildContext context) {
    if (_mapTilerKey.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 300,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Map disabled: set MAPTILER_KEY with --dart-define to load tiles.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 300,
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
                  additionalOptions: {'key': _mapTilerKey},
                  userAgentPackageName: 'com.example.community',
                ),
                MarkerLayer(
                  markers: [
                    if (currentLocation != null)
                      Marker(
                        point: currentLocation!,
                        width: 42,
                        height: 42,
                        child: const Icon(
                          Icons.person_pin_circle,
                          size: 42,
                          color: Colors.blue,
                        ),
                      ),
                    ...posts
                        .where((p) => p.latitude != null && p.longitude != null)
                        .map((p) {
                      Color markerColor;
                      switch (p.severity) {
                        case PostSeverity.low:
                          markerColor = Colors.blue;
                          break;
                        case PostSeverity.medium:
                          markerColor = Colors.orange;
                          break;
                        case PostSeverity.high:
                          markerColor = Colors.red;
                          break;
                        case PostSeverity.critical:
                          markerColor = Colors.purple;
                          break;
                      }

                      return Marker(
                        point: LatLng(p.latitude!, p.longitude!),
                        width: 30,
                        height: 30,
                        child: Icon(
                          p.category == PostCategory.medical
                              ? Icons.medical_services
                              : Icons.warning,
                          size: 30,
                          color: markerColor,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
            if (isLoadingLocation)
              const Align(
                alignment: Alignment.topCenter,
                child: _InfoBanner(
                  text: 'Fetching your location...',
                  icon: Icons.location_searching,
                ),
              ),
            if (!isLoadingLocation && locationError != null)
              Align(
                alignment: Alignment.topCenter,
                child: _ErrorBanner(
                  message: locationError!,
                  onRetry: onRetry,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

enum _HomeMenuAction { about, guidelines, help, vacation }

class _MenuContent {
  const _MenuContent({required this.title, required this.content});

  final String title;
  final String content;
}

const Map<_HomeMenuAction, _MenuContent> _menuData = {
  _HomeMenuAction.about: _MenuContent(
    title: 'About Community',
    content:
        'Community is a space for neighbors and members to share updates, learn from each other, and build local connections.',
  ),
  _HomeMenuAction.guidelines: _MenuContent(
    title: 'Community Guidelines',
    content:
        'Be respectful, avoid harmful language, protect personal privacy, and keep discussions helpful and inclusive for everyone.',
  ),
  _HomeMenuAction.help: _MenuContent(
    title: 'Help',
    content:
        'Need support? For now, contact the app owner or team directly while we prepare in-app support and reporting tools.',
  ),
};

