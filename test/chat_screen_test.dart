import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community/models/chat_models.dart';
import 'package:community/models/vacation_watch.dart';
import 'package:community/repositories/chat_repository.dart';
import 'package:community/repositories/vacation_watch_repository.dart';
import 'package:community/screens/chat_messages_screen.dart';
import 'package:community/services/auth_service.dart';
import 'package:community/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  String get uid => 'me';
  @override
  String? get displayName => 'Mic';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthService {
  @override
  User? get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

final _now = DateTime.now();
final _room = ChatRoom(
  id: 'r',
  name: 'Michael',
  participantIds: const ['me', 'michael'],
  // Michael has not opened your newest message yet.
  unreadCounts: const {'michael': 1},
);

class _Chat implements ChatRepository {
  int roomOpens = 0;
  int userOpens = 0;
  final sent = <ChatMessage>[];

  @override
  Stream<List<ChatMessage>> getMessages(String chatRoomId) => Stream.value([
    ChatMessage(
      id: '4',
      senderId: 'me',
      senderName: 'Mic',
      content: 'Appreciate it! 🙏',
      type: MessageType.text,
      timestamp: _now,
    ),
    ChatMessage(
      id: '3',
      senderId: 'michael',
      senderName: 'Michael',
      content: 'No problem! I’ll keep you posted once it’s done. 👍',
      type: MessageType.text,
      timestamp: _now.subtract(const Duration(minutes: 1)),
    ),
    ChatMessage(
      id: '2',
      senderId: 'me',
      senderName: 'Mic',
      content:
          'That’s great, thanks! If you can also bring in the packages, '
          'that would be helpful.',
      type: MessageType.text,
      timestamp: _now.subtract(const Duration(minutes: 4)),
    ),
    ChatMessage(
      id: '1',
      senderId: 'michael',
      senderName: 'Michael',
      content:
          'Hey! I’ll handle the mail sweep tomorrow. Anything else I '
          'should check?',
      type: MessageType.text,
      timestamp: _now.subtract(const Duration(minutes: 9)),
    ),
  ]).asBroadcastStream();

  @override
  Stream<ChatRoom> watchChatRoom(String chatRoomId) {
    roomOpens++;
    return Stream.value(_room);
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> getUsersStream() {
    userOpens++;
    return const Stream.empty();
  }

  @override
  Future<void> markRoomAsRead(String chatRoomId, String userId) async {}

  @override
  Future<void> sendMessage(String chatRoomId, ChatMessage message) async =>
      sent.add(message);

  final edits = <String, String>{};
  @override
  Future<void> editMessage({
    required String chatRoomId,
    required ChatMessage message,
    required String newContent,
  }) async => edits[message.id] = newContent;

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Watches implements VacationWatchRepository {
  @override
  Stream<List<VacationWatch>> watchAll() => Stream.value([
    VacationWatch(
      id: 'w',
      ownerId: 'me',
      ownerName: 'Mic',
      address: 'Muwafu Curve, Village 10, Kampala',
      startDate: _now,
      endDate: _now.add(const Duration(days: 2)),
      shifts: [
        WatchShift(
          id: 's',
          startsAt: _now,
          label: 'Coverage',
          watcherId: 'michael',
          status: WatchShiftStatus.claimed,
        ),
      ],
    ),
  ]);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Storage implements StorageService {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  testWidgets('Chat screen: banner, day chip, mic/send and long press', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chat = _Chat();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatMessagesScreen(
          authService: _Auth(),
          chatRepository: chat,
          chatRoom: _room,
          storageService: _Storage(),
          vacationWatchRepository: _Watches(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vacation Watch'), findsOneWidget);
    expect(find.textContaining('Muwafu Curve, Village 10'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    // Newest own message not yet read: single tick; older one: double.
    expect(find.byIcon(Icons.done_rounded), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);

    // Empty box shows the mic; typing turns it into send.
    expect(find.byTooltip('Record voice note'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.pump();
    expect(find.byTooltip('Send'), findsOneWidget);
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(chat.sent.single.content, 'On my way');

    // Typing never reopened the header connections.
    expect(chat.roomOpens, 1);
    expect(chat.userOpens, 1);

    // Long press opens the message options.
    await tester.longPress(find.textContaining('Appreciate it'));
    await tester.pumpAndSettle();
    expect(find.text('Reply'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The ⋮ button lets you reply to and edit messages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chat = _Chat();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatMessagesScreen(
          authService: _Auth(),
          chatRepository: chat,
          chatRoom: _room,
          storageService: _Storage(),
          vacationWatchRepository: _Watches(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Every message has a visible options button.
    expect(find.byTooltip('Reply'), findsNWidgets(2)); // Michael's two
    expect(find.byTooltip('Reply or edit'), findsNWidgets(2)); // yours

    // Reply to Michael's first message.
    await tester.tap(find.byTooltip('Reply').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.text('Replying to Michael'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Just the plants too');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(chat.sent.single.replySenderName, 'Michael');
    expect(chat.sent.single.replyToMessageId, '1');

    // Edit your newest message.
    await tester.tap(find.byTooltip('Reply or edit').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Editing message'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Appreciate it a lot!');
    await tester.pump();
    await tester.tap(find.byTooltip('Save edit'));
    await tester.pumpAndSettle();
    expect(chat.edits, {'4': 'Appreciate it a lot!'});
    expect(tester.takeException(), isNull);
  });
}
