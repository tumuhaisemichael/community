import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_post.dart';

abstract class PostRepository {
  Future<List<CommunityPost>> fetchPosts();
  Future<void> addPost(CommunityPost post);
}

class FirestorePostRepository implements PostRepository {
  FirestorePostRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<CommunityPost>> fetchPosts() async {
    final snapshot = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CommunityPost.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> addPost(CommunityPost post) async {
    await _firestore.collection('posts').add(post.toMap());
  }
}

class ExamplePostRepository implements PostRepository {
  const ExamplePostRepository();

  @override
  Future<List<CommunityPost>> fetchPosts() async {
    final rawDocs = <Map<String, dynamic>>[
      {
        'id': 'post_1',
        'authorName': 'Amina',
        'authorId': 'user_1',
        'content': 'Welcome to Community. Share your story and meet neighbors.',
        'createdAt': DateTime.now()
            .subtract(const Duration(minutes: 45))
            .toIso8601String(),
        'likes': 12,
        'category': PostCategory.general.name,
        'severity': PostSeverity.low.name,
      },
      {
        'id': 'post_2',
        'authorName': 'Michael',
        'authorId': 'user_2',
        'content': 'Anyone joining the weekend clean-up activity at the park?',
        'createdAt': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        'likes': 7,
        'category': PostCategory.general.name,
        'severity': PostSeverity.low.name,
      },
      {
        'id': 'post_3',
        'authorName': 'Grace',
        'authorId': 'user_3',
        'content': 'Book club starts next Tuesday. Suggestions are welcome!',
        'createdAt': DateTime.now()
            .subtract(const Duration(hours: 6))
            .toIso8601String(),
        'likes': 18,
        'category': PostCategory.general.name,
        'severity': PostSeverity.low.name,
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

  @override
  Future<void> addPost(CommunityPost post) async {
    // No-op for example repository
  }
}
