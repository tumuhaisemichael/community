import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';
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

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(time, now)) return DateFormat('HH:mm').format(time);
    if (now.difference(time).inDays < 7) return DateFormat('EEE').format(time);
    return DateFormat('d MMM').format(time);
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
                  height: 320,
                  child: SkeletonList(count: 4),
                );
              }

              if (snapshot.hasError) {
                return const EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load neighbours',
                  message: 'Check your connection and try again.',
                );
              }

              final users =
                  snapshot.data?.docs
                      .where((doc) => doc.id != currentUserId)
                      .toList() ??
                  [];

              if (users.isEmpty) {
                return const EmptyState(
                  icon: Icons.group_add_outlined,
                  title: 'No one else here yet',
                  message: 'Invite a neighbour to join Community.',
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userDoc = users[index];
                  final data = userDoc.data();
                  final displayName = _preferredDisplayName(data, userDoc.id);
                  final email = (data['email'] as String?)?.trim();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.watchDim,
                        child: Text(
                          displayName.isEmpty
                              ? '?'
                              : displayName[0].toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
                    ),
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
            icon: const Icon(Icons.groups_rounded),
            onPressed: _openCommunityChat,
          ),
          IconButton(
            tooltip: 'New message',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _openNewChatPicker,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.chatRepository.getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }

          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load messages',
              message: 'Check your connection and try again.',
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
                return const SkeletonList();
              }

              if (roomsSnapshot.hasError) {
                return const EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load chats',
                  message: 'Check your connection and try again.',
                );
              }

              final rooms = roomsSnapshot.data ?? [];

              if (rooms.isEmpty) {
                return EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No messages yet',
                  message:
                      'Message a neighbour privately, or say hello in the '
                      'community group.',
                  action: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _openNewChatPicker,
                        icon: const Icon(Icons.add_comment_outlined),
                        label: const Text('New message'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        onPressed: _openCommunityChat,
                        icon: const Icon(Icons.groups_rounded),
                        label: const Text('Community group'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 28),
                itemCount: rooms.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 76, endIndent: 12),
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final unreadCount = room.unreadCountFor(currentUserId);
                  final roomTitle = _resolveRoomTitle(
                    room,
                    currentUserId,
                    userNames,
                  );
                  final hasUnread = unreadCount > 0;
                  final textTheme = Theme.of(context).textTheme;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: room.isGroup
                          ? AppColors.hero
                          : AppColors.watchDim,
                      child: room.isGroup
                          ? Icon(Icons.groups_rounded, color: AppColors.accent)
                          : Text(
                              roomTitle.isEmpty
                                  ? '?'
                                  : roomTitle[0].toUpperCase(),
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                    ),
                    title: Text(
                      roomTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: hasUnread
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      room.lastMessage ?? 'No messages yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: hasUnread ? AppColors.ink : null,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (room.lastMessageTime != null)
                          Text(
                            _formatTime(room.lastMessageTime!),
                            style: textTheme.bodySmall?.copyWith(
                              color: hasUnread ? AppColors.primary : null,
                              fontWeight: hasUnread ? FontWeight.w700 : null,
                            ),
                          ),
                        if (hasUnread) ...[
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.onPrimary,
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
