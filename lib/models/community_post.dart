import 'package:cloud_firestore/cloud_firestore.dart';

enum PostCategory {
  general,
  theft,
  assault,
  suspiciousPerson,
  vandalism,
  fire,
  medical,
  accident,
  harassment,
  lostChild,
  vacationWatch,
  other,
}

enum PostSeverity {
  low,
  medium,
  high,
  critical,
}

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorId,
    required this.content,
    required this.createdAt,
    required this.likes,
    this.category = PostCategory.general,
    this.severity = PostSeverity.low,
    this.mediaUrls = const [],
    this.latitude,
    this.longitude,
    this.isAnonymous = false,
    this.isVerified = false,
    this.flags = 0,
  });

  final String id;
  final String authorName;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final int likes;
  final PostCategory category;
  final PostSeverity severity;
  final List<String> mediaUrls;
  final double? latitude;
  final double? longitude;
  final bool isAnonymous;
  final bool isVerified;
  final int flags;

  factory CommunityPost.fromMap(Map<String, dynamic> data, String documentId) {
    return CommunityPost(
      id: documentId,
      authorName: data['authorName'] as String? ?? 'Unknown member',
      authorId: data['authorId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      likes: data['likes'] as int? ?? 0,
      category: PostCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => PostCategory.general,
      ),
      severity: PostSeverity.values.firstWhere(
        (e) => e.name == data['severity'],
        orElse: () => PostSeverity.low,
      ),
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      isVerified: data['isVerified'] as bool? ?? false,
      flags: data['flags'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorName': authorName,
      'authorId': authorId,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'category': category.name,
      'severity': severity.name,
      'mediaUrls': mediaUrls,
      'latitude': latitude,
      'longitude': longitude,
      'isAnonymous': isAnonymous,
      'isVerified': isVerified,
      'flags': flags,
    };
  }
}
