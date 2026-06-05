import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import '../widgets/post_card.dart';

class SafetyLogScreen extends StatelessWidget {
  const SafetyLogScreen({
    super.key,
    required this.authService,
    required this.postRepository,
  });

  final AuthService authService;
  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    final currentUserId = authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Safety Log')),
      body: StreamBuilder<List<CommunityPost>>(
        stream: postRepository.getPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final myPosts = snapshot.data
                  ?.where((p) => p.authorId == currentUserId)
                  .toList() ??
              [];

          if (myPosts.isEmpty) {
            return const Center(
              child: Text('You have not reported any incidents yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myPosts.length,
            itemBuilder: (context, index) => PostCard(post: myPosts[index]),
          );
        },
      ),
    );
  }
}
