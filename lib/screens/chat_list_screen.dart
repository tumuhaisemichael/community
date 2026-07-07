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
  String _preferredDisplayName(Map<String, dynamic> data, String fallbackId) {
    final rawName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    if (rawName != null &&
        rawName.isNotEmpty &&
        rawName.toLowerCase() != 'new member') {
      return rawName;
    }
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return fallbackId;
  }

  String _resolveRoomTitle(
    ChatRoom room,
    String currentUserId,
    Map<String, String> userNames,
  ) {
    if (room.isGroup) {
      return room.name;
    }

    final otherUserId = room.participantIds
        .where((participantId) => participantId != currentUserId)
        .cast<String?>()
        .firstWhere(
          (participantId) => participantId != null,
          orElse: () => null,
        );

    if (otherUserId == null) {
      return room.name;
    }

    return userNames[otherUserId] ?? room.name;
  }

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
                  final displayName = _preferredDisplayName(data, userDoc.id);
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

  Future<void> _openCommunityChat() async {
    final currentUserId = widget.authService.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in first to open the group chat.')),
      );
      return;
    }

    try {
      final room = await widget.chatRepository.createOrGetCommunityChat(
        currentUserId: currentUserId,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open group chat: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Community group',
            icon: const Icon(Icons.groups_2_outlined),
            onPressed: _openCommunityChat,
          ),
          IconButton(
            tooltip: 'Start chat',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _openNewChatPicker,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.chatRepository.getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load users: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final userNames = <String, String>{
            for (final doc in snapshot.data?.docs ?? const [])
              doc.id: _preferredDisplayName(doc.data(), doc.id),
          };

          return StreamBuilder<List<ChatRoom>>(
            stream: widget.chatRepository.getChatRooms(currentUserId),
            builder: (context, roomsSnapshot) {
              if (roomsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (roomsSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load chats: ${roomsSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final rooms = roomsSnapshot.data ?? [];

              if (rooms.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No messages yet. Start a private chat or open the community group.',
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
                  final unreadCount = room.unreadCountFor(currentUserId);
                  final roomTitle = _resolveRoomTitle(
                    room,
                    currentUserId,
                    userNames,
                  );

                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(room.isGroup ? Icons.groups : Icons.person),
                    ),
                    title: Text(roomTitle),
                    subtitle: Text(
                      room.lastMessage ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (room.lastMessageTime != null)
                          Text(
                            DateFormat('HH:mm').format(room.lastMessageTime!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (unreadCount > 0) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
          );
        },
      ),
    );
  }
}
