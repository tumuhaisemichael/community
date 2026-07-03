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

  Stream<QuerySnapshot<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('users').snapshots();
  }

  Stream<ChatRoom> watchChatRoom(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .snapshots()
        .map(
          (snapshot) => ChatRoom.fromMap(snapshot.data() ?? {}, snapshot.id),
        );
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
    final roomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
    final roomSnapshot = await roomRef.get();
    final roomData = roomSnapshot.data() ?? <String, dynamic>{};
    final participants = List<String>.from(
      roomData['participantIds'] ?? const [],
    );

    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc();

    batch.set(messageRef, message.toMap());

    final updates = <String, dynamic>{
      'lastMessage': message.previewText,
      'lastMessageId': messageRef.id,
      'lastMessageTime': FieldValue.serverTimestamp(),
    };

    for (final participantId in participants) {
      updates['unreadCounts.$participantId'] = participantId == message.senderId
          ? 0
          : FieldValue.increment(1);
    }

    batch.update(roomRef, updates);

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
      'unreadCounts': {currentUserId: 0, otherUserId: 0},
      'backgroundKey': defaultChatBackgroundKey,
      'bubbleThemeKey': defaultChatBubbleThemeKey,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    return ChatRoom(
      id: newDoc.id,
      name: _buildPrivateChatName(currentUserName, otherUserName),
      participantIds: [currentUserId, otherUserId],
      isGroup: false,
      unreadCounts: {currentUserId: 0, otherUserId: 0},
      backgroundKey: defaultChatBackgroundKey,
      bubbleThemeKey: defaultChatBubbleThemeKey,
      lastMessageTime: DateTime.now(),
    );
  }

  Future<ChatRoom> createOrGetCommunityChat({
    required String currentUserId,
  }) async {
    final existing = await _firestore
        .collection('chat_rooms')
        .where('groupKey', isEqualTo: 'community')
        .limit(1)
        .get();

    final participantIds = await _loadAllUserIds();
    if (!participantIds.contains(currentUserId)) {
      participantIds.add(currentUserId);
    }

    final unreadCounts = {
      for (final participantId in participantIds) participantId: 0,
    };

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final existingUnreadCounts =
          (doc.data()['unreadCounts'] as Map<String, dynamic>? ?? {}).map(
            (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
          );
      final mergedUnreadCounts = {
        for (final participantId in participantIds)
          participantId: existingUnreadCounts[participantId] ?? 0,
      };
      await doc.reference.set({
        'name': 'Community Group',
        'participantIds': participantIds,
        'isGroup': true,
        'groupKey': 'community',
        'unreadCounts': mergedUnreadCounts,
        'backgroundKey':
            doc.data()['backgroundKey'] ?? defaultChatBackgroundKey,
        'bubbleThemeKey':
            doc.data()['bubbleThemeKey'] ?? defaultChatBubbleThemeKey,
      }, SetOptions(merge: true));
      return ChatRoom.fromMap({
        ...doc.data(),
        'name': 'Community Group',
        'participantIds': participantIds,
        'isGroup': true,
        'unreadCounts': mergedUnreadCounts,
      }, doc.id);
    }

    final newDoc = await _firestore.collection('chat_rooms').add({
      'name': 'Community Group',
      'participantIds': participantIds,
      'isGroup': true,
      'groupKey': 'community',
      'unreadCounts': unreadCounts,
      'backgroundKey': defaultChatBackgroundKey,
      'bubbleThemeKey': defaultChatBubbleThemeKey,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    return ChatRoom(
      id: newDoc.id,
      name: 'Community Group',
      participantIds: participantIds,
      isGroup: true,
      unreadCounts: unreadCounts,
      backgroundKey: defaultChatBackgroundKey,
      bubbleThemeKey: defaultChatBubbleThemeKey,
      lastMessageTime: DateTime.now(),
    );
  }

  Future<void> markRoomAsRead(String chatRoomId, String userId) {
    return _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'unreadCounts': {userId: 0},
    }, SetOptions(merge: true));
  }

  Future<void> updateChatAppearance({
    required String chatRoomId,
    required String backgroundKey,
    required String bubbleThemeKey,
  }) {
    return _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'backgroundKey': backgroundKey,
      'bubbleThemeKey': bubbleThemeKey,
    }, SetOptions(merge: true));
  }

  Future<void> editMessage({
    required String chatRoomId,
    required ChatMessage message,
    required String newContent,
  }) async {
    final roomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
    final messageRef = roomRef.collection('messages').doc(message.id);
    final roomSnapshot = await roomRef.get();
    final roomData = roomSnapshot.data() ?? <String, dynamic>{};

    await messageRef.update({
      'content': newContent,
      'editedAt': FieldValue.serverTimestamp(),
    });

    if (roomData['lastMessageId'] == message.id) {
      await roomRef.update({'lastMessage': newContent});
    }
  }

  Future<List<String>> _loadAllUserIds() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  String _buildPrivateChatName(String userAName, String userBName) {
    final first = userAName.trim().isEmpty ? 'Member' : userAName.trim();
    final second = userBName.trim().isEmpty ? 'Member' : userBName.trim();
    return '$first & $second';
  }
}
