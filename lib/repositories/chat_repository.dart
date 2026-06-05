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
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
            .toList());
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
      'lastMessage': message.type == MessageType.text ? message.content : '[Media]',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<String> createOrGetPrivateChat(String userA, String userB) async {
    final query = await _firestore
        .collection('chat_rooms')
        .where('isGroup', isEqualTo: false)
        .where('participantIds', arrayContains: userA)
        .get();

    for (final doc in query.docs) {
      final participants = List<String>.from(doc.data()['participantIds']);
      if (participants.contains(userB)) {
        return doc.id;
      }
    }

    final newDoc = await _firestore.collection('chat_rooms').add({
      'name': 'Private Chat',
      'participantIds': [userA, userB],
      'isGroup': false,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    return newDoc.id;
  }
}
