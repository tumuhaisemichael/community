import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community/models/chat_models.dart';
import 'package:community/repositories/chat_repository.dart';
import 'package:community/screens/chat_list_screen.dart';
import 'package:community/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  String get uid => 'me';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthService {
  @override
  User? get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Chat implements ChatRepository {
  int roomOpens = 0;
  int userOpens = 0;

  @override
  Stream<List<ChatRoom>> getChatRooms(String userId) {
    roomOpens++;
    final day = DateTime(2026, 7, 3);
    return Stream.value([
      ChatRoom(
        id: 'a',
        name: 'Michael',
        participantIds: const ['me', 'michael'],
        lastMessage: 'Cool 👍',
        lastMessageTime: day,
      ),
      ChatRoom(
        id: 'b',
        name: 'Community Group',
        participantIds: const ['me', 'michael', 'aisha'],
        isGroup: true,
        lastMessage: '🔥🔥🔥🚒',
        lastMessageTime: day,
        unreadCounts: const {'me': 2},
      ),
    ]);
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> getUsersStream() {
    userOpens++;
    return const Stream.empty();
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  testWidgets('Chat list: search, filters and unread badge', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chat = _Chat();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatListScreen(authService: _Auth(), chatRepository: chat),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Michael'), findsOneWidget);
    expect(find.text('Community Group'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // unread badge
    expect(find.text('3 Jul'), findsNWidgets(2));

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();
    expect(find.text('Michael'), findsNothing);
    expect(find.text('Community Group'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(TextField), 'mich');
    await tester.pumpAndSettle();
    expect(find.text('Michael'), findsOneWidget);
    expect(find.text('Community Group'), findsNothing);

    // Typing in search never reopened the chat list connections.
    expect(chat.roomOpens, 1);
    expect(chat.userOpens, 1);
    expect(tester.takeException(), isNull);
  });
}
