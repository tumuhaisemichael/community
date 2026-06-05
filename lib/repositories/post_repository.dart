import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_post.dart';

abstract class PostRepository {
  Future<List<CommunityPost>> fetchPosts();
  Stream<List<CommunityPost>> getPostsStream();
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

  @override
  Stream<List<CommunityPost>> getPostsStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommunityPost.fromMap(doc.data(), doc.id))
            .toList());
  }
}

class ExamplePostRepository implements PostRepository {
  const ExamplePostRepository();

  @override
  Future<List<CommunityPost>> fetchPosts() async {
    return [];
  }

  @override
  Future<void> addPost(CommunityPost post) async {
  }

  @override
  Stream<List<CommunityPost>> getPostsStream() {
    return Stream.value([]);
  }
}
