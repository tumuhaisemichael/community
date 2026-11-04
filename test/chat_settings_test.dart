import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community/models/chat_models.dart';
import 'package:community/repositories/chat_repository.dart';
import 'package:community/screens/chat_settings_screen.dart';
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
  String? get email => 'mic@example.com';
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
  final saved = <String, Object?>{};
  final pins = <bool>[];

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> getUsersStream() =>
      const Stream.empty();
  @override
  Stream<List<ChatRoom>> getChatRooms(String userId) => Stream.value(const []);

  @override
  Future<void> updateChatAppearance({
    required String chatRoomId,
    String? backgroundKey,
    String? bubbleThemeKey,
    int? accentColor,
    bool clearAccentColor = false,
    String? bubbleStyle,
    String? textSize,
  }) async {
    if (backgroundKey != null) saved['background'] = backgroundKey;
    if (bubbleThemeKey != null) saved['bubbleTheme'] = bubbleThemeKey;
    if (accentColor != null || clearAccentColor) saved['accent'] = accentColor;
    if (bubbleStyle != null) saved['bubbleStyle'] = bubbleStyle;
    if (textSize != null) saved['textSize'] = textSize;
  }

  @override
  Future<void> setPinned({
    required String chatRoomId,
    required String userId,
    required bool pinned,
  }) async => pins.add(pinned);

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  testWidgets('Chat settings save colour, bubble style, text size and pin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chat = _Chat();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatSettingsScreen(
          authService: _Auth(),
          chatRepository: chat,
          chatRoom: ChatRoom(
            id: 'r',
            name: 'Michael',
            participantIds: const ['me', 'michael'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Chat Appearance'), findsOneWidget);

    // Quick pick: the blue swatch.
    await tester.tap(find.bySemanticsLabel('Colour #2563EB'));
    await tester.pump();
    expect(chat.saved['accent'], 0xFF2563EB);

    // Back to the theme colour.
    await tester.tap(find.byTooltip('Use the bubble theme colour'));
    await tester.pump();
    expect(chat.saved.containsKey('accent'), isTrue);
    expect(chat.saved['accent'], isNull);

    await tester.tap(find.bySemanticsLabel('Pill bubbles'));
    await tester.pump();
    expect(chat.saved['bubbleStyle'], 'pill');

    // The section row scrolls sideways on phones.
    await tester.ensureVisible(find.text('Font & Text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Font & Text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large'));
    await tester.pump();
    expect(chat.saved['textSize'], 'large');

    await tester.tap(find.text('Keep chat on top'));
    await tester.pump();
    expect(chat.pins, [true]);
    expect(tester.takeException(), isNull);
  });
}
