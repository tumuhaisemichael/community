class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.content,
    required this.createdAt,
    required this.likes,
  });

  final String id;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final int likes;

  factory CommunityPost.fromMap(Map<String, dynamic> data, String documentId) {
    return CommunityPost(
      id: documentId,
      authorName: data['authorName'] as String? ?? 'Unknown member',
      content: data['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
      likes: data['likes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorName': authorName,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
    };
  }
}
