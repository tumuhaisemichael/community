import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, location, voice }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? mediaUrl;
  final double? latitude;
  final double? longitude;
  final String? replyToMessageId;
  final String? replyPreview;
  final String? replySenderName;
  final DateTime? editedAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.mediaUrl,
    this.latitude,
    this.longitude,
    this.replyToMessageId,
    this.replyPreview,
    this.replySenderName,
    this.editedAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      mediaUrl: data['mediaUrl'],
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      replyToMessageId: data['replyToMessageId'],
      replyPreview: data['replyPreview'],
      replySenderName: data['replySenderName'],
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type.name,
      'timestamp': FieldValue.serverTimestamp(),
      'mediaUrl': mediaUrl,
      'latitude': latitude,
      'longitude': longitude,
      'replyToMessageId': replyToMessageId,
      'replyPreview': replyPreview,
      'replySenderName': replySenderName,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
    };
  }

  String get previewText {
    switch (type) {
      case MessageType.image:
        return 'Photo';
      case MessageType.location:
        return 'Location';
      case MessageType.voice:
        return 'Voice note';
      case MessageType.video:
        return 'Video';
      default:
        return content;
    }
  }
}

class ChatRoom {
  final String id;
  final String name;
  final List<String> participantIds;
  final String? lastMessage;
  final String? lastMessageId;
  final DateTime? lastMessageTime;
  final bool isGroup;
  final Map<String, int> unreadCounts;

  ChatRoom({
    required this.id,
    required this.name,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageId,
    this.lastMessageTime,
    this.isGroup = false,
    this.unreadCounts = const {},
  });

  factory ChatRoom.fromMap(Map<String, dynamic> data, String id) {
    final rawUnreadCounts = data['unreadCounts'] as Map<String, dynamic>? ?? {};

    return ChatRoom(
      id: id,
      name: data['name'] ?? 'Chat',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageId: data['lastMessageId'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      isGroup: data['isGroup'] ?? false,
      unreadCounts: rawUnreadCounts.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageId': lastMessageId,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : FieldValue.serverTimestamp(),
      'isGroup': isGroup,
      'unreadCounts': unreadCounts,
    };
  }

  int unreadCountFor(String userId) => unreadCounts[userId] ?? 0;
}
