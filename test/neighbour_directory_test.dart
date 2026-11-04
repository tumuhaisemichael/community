import 'package:community/models/chat_models.dart';
import 'package:community/repositories/chat_repository.dart';
import 'package:community/screens/neighbor_directory_screen.dart';
import 'package:community/services/auth_service.dart';
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

class _Chat implements ChatRepository {
  final startedWith = <String>[];
  @override
  Future<ChatRoom> createOrGetPrivateChat({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
  }) async {
    startedWith.add(otherUserId);
    // Stop before opening the chat screen (needs Firebase).
    throw Exception('test stop');
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  testWidgets('Directory: filters, search and message', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chat = _Chat();
    await tester.pumpWidget(
      MaterialApp(
        home: NeighborDirectoryScreen(
          authService: _Auth(),
          chatRepository: chat,
          members: Stream.value(const [
            DirectoryMember(id: 'me', name: 'Mic', verified: true),
            DirectoryMember(
              id: 'a',
              name: 'Aisha N',
              address: 'Riverside, Kampala',
              online: true,
            ),
            DirectoryMember(id: 'd', name: 'Daniel', verified: true),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 members · 2 verified · 1 online'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);

    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    expect(find.text('Aisha N'), findsOneWidget);
    expect(find.text('Daniel'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(TextField), 'dan');
    await tester.pumpAndSettle();
    expect(find.text('Daniel'), findsOneWidget);
    expect(find.text('Aisha N'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aisha N'));
    await tester.pumpAndSettle();
    expect(find.text('Online now'), findsOneWidget);
    await tester.tap(find.text('Message Aisha'));
    await tester.pumpAndSettle();
    expect(chat.startedWith, ['a']);
    expect(tester.takeException(), isNull);
  });
}
