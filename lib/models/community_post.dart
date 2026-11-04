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

enum PostSeverity { low, medium, high, critical }

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorName,
    required this.authorId,
    required this.content,
    required this.createdAt,
    required this.likes,
    this.category = PostCategory.general,
    List<PostCategory>? categories,
    this.severity = PostSeverity.low,
    this.mediaUrls = const [],
    this.latitude,
    this.longitude,
    this.isAnonymous = false,
    this.isVerified = false,
    this.flags = 0,
    this.likedBy = const [],
    this.flaggedBy = const [],
  }) : _categories = categories;

  final String id;
  final String authorName;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final int likes;

  /// Main category: the first one picked. Used for the icon and colour.
  final PostCategory category;

  final List<PostCategory>? _categories;

  /// Every category picked when reporting (always includes [category]).
  List<PostCategory> get categories => _categories ?? [category];
  final PostSeverity severity;
  final List<String> mediaUrls;
  final double? latitude;
  final double? longitude;
  final bool isAnonymous;
  final bool isVerified;
  final int flags;
  final List<String> likedBy;
  final List<String> flaggedBy;

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
      categories: _parseCategories(data),
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
      likedBy: List<String>.from(data['likedBy'] ?? const []),
      flaggedBy: List<String>.from(data['flaggedBy'] ?? const []),
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
      'categories': [for (final c in categories) c.name],
      'severity': severity.name,
      'mediaUrls': mediaUrls,
      'latitude': latitude,
      'longitude': longitude,
      'isAnonymous': isAnonymous,
      'isVerified': isVerified,
      'flags': flags,
      'likedBy': likedBy,
      'flaggedBy': flaggedBy,
    };
  }

  /// "Theft, Assault" for posts with several categories.
  String get categoriesLabel => categories.map((c) => c.label).join(', ');

  static List<PostCategory>? _parseCategories(Map<String, dynamic> data) {
    final raw = data['categories'];
    if (raw is! List) return null;
    final parsed = [
      for (final name in raw)
        for (final c in PostCategory.values)
          if (c.name == name) c,
    ];
    return parsed.isEmpty ? null : parsed;
  }

  bool isLikedBy(String userId) =>
      userId.isNotEmpty && likedBy.contains(userId);

  bool isFlaggedBy(String userId) =>
      userId.isNotEmpty && flaggedBy.contains(userId);
}

class PostComment {
  const PostComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  factory PostComment.fromMap(Map<String, dynamic> data, String documentId) {
    return PostComment(
      id: documentId,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Member',
      content: data['content'] as String? ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

extension PostCategoryLabel on PostCategory {
  String get label {
    switch (this) {
      case PostCategory.suspiciousPerson:
        return 'Suspicious person';
      case PostCategory.lostChild:
        return 'Lost child';
      case PostCategory.vacationWatch:
        return 'Vacation watch';
      default:
        return '${name[0].toUpperCase()}${name.substring(1)}';
    }
  }
}

extension PostSeverityLabel on PostSeverity {
  String get label {
    switch (this) {
      case PostSeverity.low:
        return 'Routine';
      case PostSeverity.medium:
        return 'Watch';
      case PostSeverity.high:
        return 'Urgent';
      case PostSeverity.critical:
        return 'Critical';
    }
  }

  bool get isSerious =>
      this == PostSeverity.high || this == PostSeverity.critical;
}
