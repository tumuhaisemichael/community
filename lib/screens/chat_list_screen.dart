import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../services/auth_service.dart';
import 'chat_messages_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({
    super.key,
    required this.authService,
    required this.chatRepository,
  });

  final AuthService authService;
  final ChatRepository chatRepository;

  @override
  Widget build(BuildContext context) {
    final currentUserId = authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () {
              // Feature #13: Implementation for creating neighborhood groups
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: chatRepository.getChatRooms(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
            return const Center(
              child: Text('No messages yet. Start a conversation!'),
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
                        authService: authService,
                        chatRepository: chatRepository,
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
