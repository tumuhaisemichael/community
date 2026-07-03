import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_models.dart';

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<ChatRoom>> getChatRooms(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs
              .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
              .toList();

          rooms.sort((a, b) {
            final aTime = a.lastMessageTime;
            final bTime = b.lastMessageTime;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return rooms;
        });
  }

  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> sendMessage(String chatRoomId, ChatMessage message) async {
    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc();

    batch.set(messageRef, message.toMap());

    final roomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
    batch.update(roomRef, {
      'lastMessage': message.type == MessageType.text
          ? message.content
          : '[Media]',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<ChatRoom> createOrGetPrivateChat({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    final query = await _firestore
        .collection('chat_rooms')
        .where('participantIds', arrayContains: currentUserId)
        .get();

    for (final doc in query.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participantIds'] ?? []);
      final isGroup = data['isGroup'] as bool? ?? false;

      if (!isGroup && participants.contains(otherUserId)) {
        return ChatRoom.fromMap(data, doc.id);
      }
    }

    final newDoc = await _firestore.collection('chat_rooms').add({
      'name': _buildPrivateChatName(currentUserName, otherUserName),
      'participantIds': [currentUserId, otherUserId],
      'isGroup': false,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    return ChatRoom(
      id: newDoc.id,
      name: _buildPrivateChatName(currentUserName, otherUserName),
      participantIds: [currentUserId, otherUserId],
      isGroup: false,
      lastMessageTime: DateTime.now(),
    );
  }

  String _buildPrivateChatName(String userAName, String userBName) {
    final first = userAName.trim().isEmpty ? 'Member' : userAName.trim();
    final second = userBName.trim().isEmpty ? 'Member' : userBName.trim();
    return '$first & $second';
  }
}
