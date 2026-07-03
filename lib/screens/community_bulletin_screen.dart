import 'package:flutter/material.dart';
import 'package:community/widgets/post_card.dart';
import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';

class CommunityBulletinScreen extends StatefulWidget {
  const CommunityBulletinScreen({
    super.key,
    required this.authService,
    required this.postRepository,
  });

  final AuthService authService;
  final PostRepository postRepository;

  @override
  State<CommunityBulletinScreen> createState() =>
      _CommunityBulletinScreenState();
}

class _CommunityBulletinScreenState extends State<CommunityBulletinScreen> {
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final user = widget.authService.currentUser;
      final post = CommunityPost(
        id: '',
        authorName: user?.displayName ?? user?.email ?? 'Member',
        authorId: user?.uid ?? '',
        content: text,
        createdAt: DateTime.now(),
        likes: 0,
        category: PostCategory.general,
      );

      await widget.postRepository.addPost(post);
      _contentController.clear();
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Bulletin')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: 'Share an announcement...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSubmitting ? null : _submitPost,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CommunityPost>>(
              stream: widget.postRepository.getPostsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final posts = snapshot.data ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => PostCard(
                    post: posts[index],
                    authService: widget.authService,
                    postRepository: widget.postRepository,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
