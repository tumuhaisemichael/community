import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/home_tone.dart';
import '../widgets/hero_header.dart';
import '../services/live_value.dart';
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

enum _ChatFilter { all, direct, groups }

class _ChatListScreenState extends State<ChatListScreen> {
  // Opened once: typing in the search box redraws the list on every letter
  // and must never reconnect these.
  late final LiveValue<QuerySnapshot<Map<String, dynamic>>> _users = LiveValue(
    widget.chatRepository.getUsersStream(),
  );
  late final LiveValue<List<ChatRoom>> _rooms = LiveValue(
    widget.chatRepository.getChatRooms(
      widget.authService.currentUser?.uid ?? '',
    ),
  );
  final TextEditingController _search = TextEditingController();
  _ChatFilter _filter = _ChatFilter.all;

  @override
  void dispose() {
    _users.close();
    _rooms.close();
    _search.dispose();
    super.dispose();
  }

  static bool _isOnline(Map<String, dynamic>? data) {
    final updated = data?['locationUpdatedAt'];
    return updated is Timestamp &&
        DateTime.now().difference(updated.toDate()) <
            const Duration(minutes: 15);
  }

  String? _otherId(ChatRoom room, String me) {
    if (room.isGroup) return null;
    for (final id in room.participantIds) {
      if (id != me) return id;
    }
    return null;
  }

  void _openRoom(ChatRoom room) {
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
  }

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
    if (DateUtils.isSameDay(time, now)) {
      return DateFormat('h:mm a').format(time);
    }
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: HomeTone.canvas,
        child: Column(
          children: [
            TabHeroHeader(
              title: 'Messages',
              subtitle: 'Chat with your neighbours and groups',
              actions: [
                HeaderSquareButton(
                  icon: Icons.groups_rounded,
                  tooltip: 'Community group',
                  onPressed: _openCommunityChat,
                ),
                HeaderSquareButton(
                  icon: Icons.edit_square,
                  tooltip: 'New message',
                  onPressed: _openNewChatPicker,
                ),
              ],
              bottom: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Column(
                  children: [
                    _SearchField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // Scrolls sideways if the chips do not fit (small
                    // phones or large text).
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (filter, label, icon) in const [
                            (_ChatFilter.all, 'All', null),
                            (
                              _ChatFilter.direct,
                              'Direct',
                              Icons.person_outline_rounded,
                            ),
                            (
                              _ChatFilter.groups,
                              'Groups',
                              Icons.groups_outlined,
                            ),
                          ]) ...[
                            _FilterChip(
                              label: label,
                              icon: icon,
                              selected: _filter == filter,
                              onTap: () => setState(() => _filter = filter),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _users.stream,
                initialData: _users.latest,
                builder: (context, usersSnapshot) {
                  final users = <String, Map<String, dynamic>>{
                    for (final doc in usersSnapshot.data?.docs ?? const [])
                      doc.id: doc.data(),
                  };
                  final userNames = <String, String>{
                    for (final entry in users.entries)
                      entry.key: _preferredDisplayName(entry.value, entry.key),
                  };

                  return StreamBuilder<List<ChatRoom>>(
                    stream: _rooms.stream,
                    initialData: _rooms.latest,
                    builder: (context, roomsSnapshot) {
                      if (roomsSnapshot.hasError) {
                        return const _ListMessage(
                          icon: Icons.wifi_off_rounded,
                          title: 'Could not load chats',
                          message: 'Check your connection and try again.',
                        );
                      }
                      if (!roomsSnapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: SkeletonList(count: 3),
                        );
                      }

                      final allRooms = roomsSnapshot.data!;
                      if (allRooms.isEmpty) {
                        return _ListMessage(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No messages yet',
                          message:
                              'Message a neighbour privately, or say hello '
                              'in the community group.',
                          actions: [
                            FilledButton.icon(
                              onPressed: _openNewChatPicker,
                              style: FilledButton.styleFrom(
                                backgroundColor: HomeTone.violet,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.edit_square, size: 18),
                              label: const Text('New message'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _openCommunityChat,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: HomeTone.violet,
                                minimumSize: const Size(0, 44),
                                side: const BorderSide(color: HomeTone.violet),
                              ),
                              icon: const Icon(Icons.groups_rounded, size: 18),
                              label: const Text('Community group'),
                            ),
                          ],
                        );
                      }

                      final query = _search.text.trim().toLowerCase();
                      final rooms =
                          allRooms.where((room) {
                              if (_filter == _ChatFilter.direct &&
                                  room.isGroup) {
                                return false;
                              }
                              if (_filter == _ChatFilter.groups &&
                                  !room.isGroup) {
                                return false;
                              }
                              if (query.isEmpty) return true;
                              final title = _resolveRoomTitle(
                                room,
                                currentUserId,
                                userNames,
                              ).toLowerCase();
                              return title.contains(query) ||
                                  (room.lastMessage ?? '')
                                      .toLowerCase()
                                      .contains(query);
                            }).toList()
                            // Chats kept on top come first; otherwise the
                            // order from the server (newest first) stays.
                            ..sort((a, b) {
                              final pa = a.isPinnedBy(currentUserId) ? 0 : 1;
                              final pb = b.isPinnedBy(currentUserId) ? 0 : 1;
                              return pa.compareTo(pb);
                            });

                      if (rooms.isEmpty) {
                        return _ListMessage(
                          icon: Icons.search_off_rounded,
                          title: 'No chats match',
                          message: query.isEmpty
                              ? 'Try another filter.'
                              : 'Nothing found for "${_search.text.trim()}".',
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          bottomInset + 24,
                        ),
                        itemCount: rooms.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          final otherId = _otherId(room, currentUserId);
                          return _ChatTile(
                            title: _resolveRoomTitle(
                              room,
                              currentUserId,
                              userNames,
                            ),
                            isGroup: room.isGroup,
                            online:
                                otherId != null && _isOnline(users[otherId]),
                            lastMessage: room.lastMessage ?? 'No messages yet',
                            time: room.lastMessageTime == null
                                ? null
                                : _formatTime(room.lastMessageTime!),
                            unread: room.unreadCountFor(currentUserId),
                            pinned: room.isPinnedBy(currentUserId),
                            onTap: () => _openRoom(room),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    style: const TextStyle(color: HomeTone.ink, fontSize: 15),
    cursorColor: HomeTone.violet,
    decoration: InputDecoration(
      hintText: 'Search messages…',
      hintStyle: const TextStyle(color: HomeTone.muted, fontSize: 15),
      prefixIcon: const Icon(Icons.search_rounded, color: HomeTone.muted),
      suffixIcon: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => value.text.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded, color: HomeTone.muted),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
      filled: true,
      fillColor: const Color(0xFFF1EDFA),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(99),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(99),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(99),
        borderSide: const BorderSide(color: HomeTone.violet),
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? HomeTone.violet : const Color(0xFFF1EDFA),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: icon == null ? 24 : 16,
            vertical: 9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : HomeTone.ink,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : HomeTone.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.title,
    required this.isGroup,
    required this.online,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.onTap,
    this.pinned = false,
  });

  final bool pinned;
  final String title;
  final bool isGroup;
  final bool online;
  final String lastMessage;
  final String? time;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unread > 0;
    return Semantics(
      button: true,
      label: [
        title,
        if (online) 'online',
        if (pinned) 'kept on top',
        if (hasUnread) '$unread unread',
        lastMessage,
        ?time,
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: HomeTone.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HomeTone.border),
          boxShadow: HomeTone.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Violet edge marks chats with unread messages.
                  Container(
                    width: 4,
                    color: hasUnread ? HomeTone.violet : Colors.transparent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 27,
                                backgroundColor: HomeTone.violetDim,
                                child: isGroup
                                    ? const Icon(
                                        Icons.groups_rounded,
                                        color: HomeTone.violet,
                                        size: 28,
                                      )
                                    : Text(
                                        title.isEmpty
                                            ? '?'
                                            : title[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: HomeTone.violet,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                              if (online)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 15,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: HomeTone.ink,
                                    fontSize: 16,
                                    fontWeight: hasUnread
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: hasUnread
                                        ? HomeTone.ink
                                        : HomeTone.muted,
                                    fontSize: 14,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (time != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (pinned) ...[
                                      const Icon(
                                        Icons.push_pin_rounded,
                                        size: 14,
                                        color: HomeTone.muted,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      time!,
                                      style: TextStyle(
                                        color: hasUnread
                                            ? HomeTone.violet
                                            : HomeTone.muted,
                                        fontSize: 12.5,
                                        fontWeight: hasUnread
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              if (hasUnread) ...[
                                const SizedBox(height: 8),
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: HomeTone.violet,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: HomeTone.violetDim,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: HomeTone.violet, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: HomeTone.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: HomeTone.muted, fontSize: 13.5),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    ),
  );
}
