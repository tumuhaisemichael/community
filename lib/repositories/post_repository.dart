import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_post.dart';

abstract class PostRepository {
  Future<List<CommunityPost>> fetchPosts();
  Stream<List<CommunityPost>> getPostsStream();
  Future<void> addPost(CommunityPost post);
  Future<void> toggleLike({required String postId, required String userId});
  Future<void> toggleFlag({required String postId, required String userId});
  Future<void> setVerification({
    required String postId,
    required bool isVerified,
  });
  Stream<List<PostComment>> getCommentsStream(String postId);
  Future<void> addComment({
    required String postId,
    required PostComment comment,
  });
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
  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final likedBy = List<String>.from(data['likedBy'] ?? const []);
      final hasLiked = likedBy.contains(userId);

      if (hasLiked) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }

      transaction.update(postRef, {
        'likedBy': likedBy,
        'likes': likedBy.length,
      });
    });
  }

  @override
  Future<void> toggleFlag({
    required String postId,
    required String userId,
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final flaggedBy = List<String>.from(data['flaggedBy'] ?? const []);
      final hasFlagged = flaggedBy.contains(userId);

      if (hasFlagged) {
        flaggedBy.remove(userId);
      } else {
        flaggedBy.add(userId);
      }

      transaction.update(postRef, {
        'flaggedBy': flaggedBy,
        'flags': flaggedBy.length,
      });
    });
  }

  @override
  Future<void> setVerification({
    required String postId,
    required bool isVerified,
  }) {
    return _firestore.collection('posts').doc(postId).update({
      'isVerified': isVerified,
    });
  }

  @override
  Stream<List<PostComment>> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PostComment.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  @override
  Future<void> addComment({
    required String postId,
    required PostComment comment,
  }) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .add(comment.toMap());
  }

  @override
  Stream<List<CommunityPost>> getPostsStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommunityPost.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }
}

class ExamplePostRepository implements PostRepository {
  const ExamplePostRepository();

  @override
  Future<List<CommunityPost>> fetchPosts() async {
    return [];
  }

  @override
  Future<void> addPost(CommunityPost post) async {}

  @override
  Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {}

  @override
  Future<void> toggleFlag({
    required String postId,
    required String userId,
  }) async {}

  @override
  Future<void> setVerification({
    required String postId,
    required bool isVerified,
  }) async {}

  @override
  Stream<List<PostComment>> getCommentsStream(String postId) {
    return Stream.value(const []);
  }

  @override
  Future<void> addComment({
    required String postId,
    required PostComment comment,
  }) async {}

  @override
  Stream<List<CommunityPost>> getPostsStream() {
    return Stream.value([]);
  }
}
