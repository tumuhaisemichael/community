import 'package:flutter/material.dart';
import '../widgets/community_ui.dart';
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
      appBar: AppBar(title: const Text('My safety log')),
      body: StreamBuilder<List<CommunityPost>>(
        stream: postRepository.getPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }

          final myPosts =
              snapshot.data
                  ?.where((p) => p.authorId == currentUserId)
                  .toList() ??
              [];

          if (myPosts.isEmpty) {
            return const EmptyState(
              icon: Icons.edit_note_rounded,
              title: 'No reports yet',
              message:
                  'Incidents you report appear here, so you can keep track of '
                  'them.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: myPosts.length + 1,
            itemBuilder: (context, index) => index == 0
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PageIntro(
                      'You have reported ${myPosts.length} '
                      'incident${myPosts.length == 1 ? '' : 's'}.',
                    ),
                  )
                : PostCard(
                    post: myPosts[index - 1],
                    authService: authService,
                    postRepository: postRepository,
                  ),
          );
        },
      ),
    );
  }
}
