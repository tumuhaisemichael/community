import 'package:flutter/material.dart';

import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.postRepository,
  });

  final AuthService authService;
  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    final userEmail = authService.currentUser?.email ?? 'Member';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Home'),
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
              PopupMenuItem(value: _HomeMenuAction.help, child: Text('Help')),
            ],
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: authService.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<CommunityPost>>(
        future: postRepository.fetchPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load posts.'));
          }

          final posts = snapshot.data ?? const <CommunityPost>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Welcome, $userEmail',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Here are community updates:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ...posts.map((post) => _PostCard(post: post)),
            ],
          );
        },
      ),
    );
  }

  void _showMenuContent(BuildContext context, _HomeMenuAction action) {
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
}

enum _HomeMenuAction { about, guidelines, help }

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

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final createdAt =
        '${post.createdAt.hour.toString().padLeft(2, '0')}:${post.createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  post.authorName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(createdAt),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.content),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text('${post.likes} likes'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
