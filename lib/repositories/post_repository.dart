import '../models/community_post.dart';

abstract class PostRepository {
  Future<List<CommunityPost>> fetchPosts();
}

class ExamplePostRepository implements PostRepository {
  const ExamplePostRepository();

  @override
  Future<List<CommunityPost>> fetchPosts() async {
    final rawDocs = <Map<String, dynamic>>[
      {
        'id': 'post_1',
        'authorName': 'Amina',
        'content': 'Welcome to Community. Share your story and meet neighbors.',
        'createdAt': DateTime.now()
            .subtract(const Duration(minutes: 45))
            .toIso8601String(),
        'likes': 12,
      },
      {
        'id': 'post_2',
        'authorName': 'Michael',
        'content': 'Anyone joining the weekend clean-up activity at the park?',
        'createdAt': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        'likes': 7,
      },
      {
        'id': 'post_3',
        'authorName': 'Grace',
        'content': 'Book club starts next Tuesday. Suggestions are welcome!',
        'createdAt': DateTime.now()
            .subtract(const Duration(hours: 6))
            .toIso8601String(),
        'likes': 18,
      },
    ];

    return rawDocs
        .map(
          (doc) => CommunityPost.fromMap(
            doc,
            doc['id'] as String? ??
                DateTime.now().millisecondsSinceEpoch.toString(),
          ),
        )
        .toList(growable: false);
  }
}
