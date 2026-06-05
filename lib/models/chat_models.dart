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
    };
  }
}

class ChatRoom {
  final String id;
  final String name;
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool isGroup;

  ChatRoom({
    required this.id,
    required this.name,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageTime,
    this.isGroup = false,
  });

  factory ChatRoom.fromMap(Map<String, dynamic> data, String id) {
    return ChatRoom(
      id: id,
      name: data['name'] ?? 'Chat',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      isGroup: data['isGroup'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : FieldValue.serverTimestamp(),
      'isGroup': isGroup,
    };
  }
}
