import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../services/auth_service.dart';
import 'chat_messages_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.authService,
    required this.chatRepository,
  });

  final AuthService authService;
  final ChatRepository chatRepository;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Future<void> _openNewChatPicker() async {
    final currentUser = widget.authService.currentUser;
    final currentUserId = currentUser?.uid ?? '';

    if (currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first to start chatting.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load users: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final users =
                  snapshot.data?.docs
                      .where((doc) => doc.id != currentUserId)
                      .toList() ??
                  [];

              if (users.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No other users are available yet. Make sure each account has a document in the users collection.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userDoc = users[index];
                  final data = userDoc.data();
                  final displayName =
                      (data['displayName'] as String?)?.trim().isNotEmpty ==
                          true
                      ? (data['displayName'] as String).trim()
                      : ((data['email'] as String?)?.trim().isNotEmpty == true
                            ? (data['email'] as String).trim()
                            : 'Member');
                  final email = (data['email'] as String?)?.trim();

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(displayName),
                    subtitle: email == null || email.isEmpty
                        ? null
                        : Text(email),
                    onTap: () async {
                      final navigator = Navigator.of(sheetContext);
                      navigator.pop();

                      try {
                        final room = await widget.chatRepository
                            .createOrGetPrivateChat(
                              currentUserId: currentUserId,
                              currentUserName:
                                  currentUser?.displayName ??
                                  currentUser?.email ??
                                  'Member',
                              otherUserId: userDoc.id,
                              otherUserName: displayName,
                            );

                        if (!mounted) return;
                        await Navigator.of(this.context).push(
                          MaterialPageRoute(
                            builder: (context) => ChatMessagesScreen(
                              authService: widget.authService,
                              chatRepository: widget.chatRepository,
                              chatRoom: room,
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Could not start chat: $error'),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Start chat',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _openNewChatPicker,
          ),
        ],
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: widget.chatRepository.getChatRooms(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load chats: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No messages yet. Start a conversation with another user.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _openNewChatPicker,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Start Chat'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(room.isGroup ? Icons.groups : Icons.person),
                ),
                title: Text(room.name),
                subtitle: Text(
                  room.lastMessage ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: room.lastMessageTime != null
                    ? Text(
                        DateFormat('HH:mm').format(room.lastMessageTime!),
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatMessagesScreen(
                        authService: widget.authService,
                        chatRepository: widget.chatRepository,
                        chatRoom: room,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
