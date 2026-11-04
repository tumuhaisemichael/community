import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../widgets/community_ui.dart';
import '../theme/app_theme.dart';
import '../models/chat_models.dart';
import '../models/vacation_watch.dart';
import '../repositories/chat_repository.dart';
import '../repositories/vacation_watch_repository.dart';
import '../services/auth_service.dart';
import '../services/live_value.dart';
import '../services/ui_preferences.dart';
import '../services/storage_service.dart';
import '../theme/chat_appearance.dart';
import 'chat_settings_screen.dart';
import 'vacation_watch_screen.dart';

enum _MessageAction { reply, edit }

class ChatMessagesScreen extends StatefulWidget {
  ChatMessagesScreen({
    super.key,
    required this.authService,
    required this.chatRepository,
    required this.chatRoom,
    StorageService? storageService,
    this.vacationWatchRepository,
  }) : storageService = storageService ?? StorageService();

  final AuthService authService;
  final ChatRepository chatRepository;
  final ChatRoom chatRoom;
  final StorageService storageService;

  /// Used to show a shared Vacation Watch above the messages. Defaults to
  /// the Firestore-backed repository; tests pass their own.
  final VacationWatchRepository? vacationWatchRepository;

  @override
  State<ChatMessagesScreen> createState() => _ChatMessagesScreenState();
}

class _ChatMessagesScreenState extends State<ChatMessagesScreen> {
  static const String _mapTilerKey = 'uWW7vmIm5gtAhwbF20VH';

  final _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late final Stream<List<ChatMessage>> _messagesStream;
  StreamSubscription<List<ChatMessage>>? _readReceiptSubscription;
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;

  // Opened once: typing (which redraws the send button) must never
  // reconnect these or flash the header.
  late final LiveValue<QuerySnapshot<Map<String, dynamic>>> _users = LiveValue(
    widget.chatRepository.getUsersStream(),
  );
  late final LiveValue<ChatRoom> _room = LiveValue(
    widget.chatRepository.watchChatRoom(widget.chatRoom.id),
  );
  late final LiveValue<List<VacationWatch>> _watches = LiveValue(
    (widget.vacationWatchRepository ?? VacationWatchRepository()).watchAll(),
  );

  @override
  void initState() {
    super.initState();
    _messagesStream = widget.chatRepository.getMessages(widget.chatRoom.id);
    _startReadReceipts();
  }

  @override
  void dispose() {
    _users.close();
    _room.close();
    _watches.close();
    _readReceiptSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _startReadReceipts() {
    final currentUserId = widget.authService.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    widget.chatRepository.markRoomAsRead(widget.chatRoom.id, currentUserId);
    _readReceiptSubscription = _messagesStream.listen((_) {
      widget.chatRepository.markRoomAsRead(widget.chatRoom.id, currentUserId);
    });
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

  String _resolveRoomTitle(ChatRoom room, Map<String, String> userNames) {
    if (room.isGroup) {
      return room.name;
    }

    final currentUserId = widget.authService.currentUser?.uid ?? '';
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

  String _currentSenderName() {
    final user = widget.authService.currentUser;
    if (user?.displayName?.trim().isNotEmpty == true) {
      return user!.displayName!.trim();
    }
    if (user?.email?.trim().isNotEmpty == true) {
      return user!.email!.split('@').first;
    }
    return 'Member';
  }

  ChatMessage _buildDraftMessage({
    required MessageType type,
    required String content,
    String? mediaUrl,
    double? latitude,
    double? longitude,
  }) {
    final user = widget.authService.currentUser;

    return ChatMessage(
      id: '',
      senderId: user?.uid ?? '',
      senderName: _currentSenderName(),
      content: content,
      type: type,
      timestamp: DateTime.now(),
      mediaUrl: mediaUrl,
      latitude: latitude,
      longitude: longitude,
      replyToMessageId: _replyingTo?.id,
      replyPreview: _replyingTo?.previewText,
      replySenderName: _replyingTo?.senderName,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      if (_editingMessage != null) {
        await widget.chatRepository.editMessage(
          chatRoomId: widget.chatRoom.id,
          message: _editingMessage!,
          newContent: text,
        );
      } else {
        final message = _buildDraftMessage(
          type: MessageType.text,
          content: text,
        );
        await widget.chatRepository.sendMessage(widget.chatRoom.id, message);
      }

      _messageController.clear();
      if (mounted) {
        setState(() {
          _replyingTo = null;
          _editingMessage = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send message: $error')));
    }
  }

  Future<void> _sendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final urls = await widget.storageService.uploadImages([image]);
      if (urls.isEmpty) return;

      final message = _buildDraftMessage(
        type: MessageType.image,
        content: 'Shared a photo',
        mediaUrl: urls.first,
      );

      await widget.chatRepository.sendMessage(widget.chatRoom.id, message);
      if (!mounted) return;
      setState(() {
        _replyingTo = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send photo: $error')));
    }
  }

  Future<void> _sendLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final message = _buildDraftMessage(
        type: MessageType.location,
        content: 'Shared location',
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await widget.chatRepository.sendMessage(widget.chatRoom.id, message);
      if (!mounted) return;
      setState(() {
        _replyingTo = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not get location: $error')));
    }
  }

  Future<void> _sendVoiceNote(String localPath) async {
    try {
      final url = await widget.storageService.uploadVoiceNote(localPath);
      final message = _buildDraftMessage(
        type: MessageType.voice,
        content: 'Voice note',
        mediaUrl: url,
      );
      await widget.chatRepository.sendMessage(widget.chatRoom.id, message);
      if (!mounted) return;
      setState(() {
        _replyingTo = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send voice note: $error')),
      );
    }
  }

  void _showMediaOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const IconBadge(icon: Icons.photo_outlined, size: 40),
              title: const Text('Photo'),
              subtitle: const Text('Choose from your gallery'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: const IconBadge(
                icon: Icons.location_on_outlined,
                size: 40,
              ),
              title: const Text('My location'),
              subtitle: const Text('Share where you are right now'),
              onTap: () {
                Navigator.pop(context);
                _sendLocation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVoiceRecorder() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _VoiceNoteRecorderSheet(onSend: _sendVoiceNote),
    );
  }

  Future<void> _openChatSettings(ChatRoom room) async {
    final selectedRoom = await Navigator.push<ChatRoom>(
      context,
      MaterialPageRoute(
        builder: (context) => ChatSettingsScreen(
          authService: widget.authService,
          chatRepository: widget.chatRepository,
          chatRoom: room,
        ),
      ),
    );

    if (!mounted || selectedRoom == null || selectedRoom.id == room.id) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatMessagesScreen(
          authService: widget.authService,
          chatRepository: widget.chatRepository,
          chatRoom: selectedRoom,
        ),
      ),
    );
  }

  void _beginReply(ChatMessage message) {
    setState(() {
      _replyingTo = message;
      _editingMessage = null;
    });
  }

  void _beginEdit(ChatMessage message) {
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
      _messageController.text = message.content;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
    });
  }

  void _clearComposerMode() {
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
    });
  }

  void _handleMessageAction(_MessageAction action, ChatMessage message) {
    switch (action) {
      case _MessageAction.reply:
        _beginReply(message);
      case _MessageAction.edit:
        _beginEdit(message);
    }
  }

  Widget? _buildComposerBanner() {
    if (_editingMessage != null) {
      return _ComposerBanner(
        icon: Icons.edit_outlined,
        title: 'Editing message',
        subtitle: _editingMessage!.content,
        onClose: _clearComposerMode,
      );
    }

    if (_replyingTo != null) {
      return _ComposerBanner(
        icon: Icons.reply,
        title: 'Replying to ${_replyingTo!.senderName}',
        subtitle: _replyingTo!.previewText,
        onClose: _clearComposerMode,
      );
    }

    return null;
  }

  String? _otherParticipant(ChatRoom room, String me) {
    if (room.isGroup) return null;
    for (final id in room.participantIds) {
      if (id != me) return id;
    }
    return null;
  }

  static bool _isOnline(Map<String, dynamic>? data) {
    final updated = data?['locationUpdatedAt'];
    return updated is Timestamp &&
        DateTime.now().difference(updated.toDate()) <
            const Duration(minutes: 15);
  }

  /// A current or upcoming Vacation Watch that links the two people in a
  /// private chat (one is away, the other has claimed one of the days).
  VacationWatch? _sharedWatch(
    List<VacationWatch> watches,
    String me,
    String other,
  ) {
    final today = DateTime.now();
    final matches = watches.where((w) {
      if (w.status == VacationWatchStatus.cancelled ||
          w.status == VacationWatchStatus.completed ||
          w.endDate.isBefore(DateTime(today.year, today.month, today.day))) {
        return false;
      }
      bool covers(String person) =>
          w.shifts.any((shift) => shift.watcherId == person) ||
          w.watcherIds.contains(person);
      return (w.ownerId == other && covers(me)) ||
          (w.ownerId == me && covers(other));
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
    return matches.isEmpty ? null : matches.first;
  }

  void _openVacationWatch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VacationWatchScreen(authService: widget.authService),
      ),
    );
  }

  Future<void> _showMessageOptions(ChatMessage message, bool isMe) async {
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: ChatTone.text),
              title: const Text(
                'Reply',
                style: TextStyle(color: ChatTone.text),
              ),
              onTap: () => Navigator.pop(context, _MessageAction.reply),
            ),
            if (isMe && message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: ChatTone.text),
                title: const Text(
                  'Edit',
                  style: TextStyle(color: ChatTone.text),
                ),
                onTap: () => Navigator.pop(context, _MessageAction.edit),
              ),
            if (message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: ChatTone.text),
                title: const Text(
                  'Copy text',
                  style: TextStyle(color: ChatTone.text),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
    if (action != null && mounted) _handleMessageAction(action, message);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.authService.currentUser?.uid ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
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

          return StreamBuilder<ChatRoom>(
            stream: _room.stream,
            initialData: _room.latest ?? widget.chatRoom,
            builder: (context, roomSnapshot) {
              final room = roomSnapshot.data ?? widget.chatRoom;
              final roomTitle = _resolveRoomTitle(room, userNames);
              final otherId = _otherParticipant(room, currentUserId);
              final backgroundPreset = ChatAppearanceCatalog.backgroundByKey(
                room.backgroundKey,
              );
              final bubblePreset = ChatAppearanceCatalog.chatBubbleByKey(
                room.bubbleThemeKey,
              );
              final accent = room.accentColor == null
                  ? null
                  : Color(room.accentColor!);
              final textScale = switch (room.textSize) {
                'small' => .9,
                'large' => 1.15,
                _ => 1.0,
              };
              final otherUnread = otherId == null
                  ? 0
                  : room.unreadCounts[otherId] ?? 0;

              return Scaffold(
                backgroundColor: backgroundPreset.colors.last,
                body: DecoratedBox(
                  decoration: backgroundPreset.chatDecoration(),
                  child: Column(
                    children: [
                      _ChatHeader(
                        title: roomTitle,
                        isGroup: room.isGroup,
                        subtitle: room.isGroup
                            ? '${room.participantIds.length} members'
                            : _isOnline(users[otherId])
                            ? 'Online'
                            : null,
                        online: !room.isGroup && _isOnline(users[otherId]),
                        onSettings: () => _openChatSettings(room),
                      ),
                      if (otherId != null)
                        StreamBuilder<List<VacationWatch>>(
                          stream: _watches.stream,
                          initialData: _watches.latest,
                          builder: (context, snapshot) {
                            final watch = _sharedWatch(
                              snapshot.data ?? const [],
                              currentUserId,
                              otherId,
                            );
                            return AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              child: watch == null
                                  ? const SizedBox(width: double.infinity)
                                  : _VacationBanner(
                                      watch: watch,
                                      onTap: _openVacationWatch,
                                    ),
                            );
                          },
                        ),
                      Expanded(
                        child: StreamBuilder<List<ChatMessage>>(
                          stream: _messagesStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Center(
                                child: Text(
                                  'Could not load messages. Check your '
                                  'connection.',
                                  style: TextStyle(color: ChatTone.muted),
                                ),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: ChatTone.accent,
                                ),
                              );
                            }
                            final messages = snapshot.data!;
                            if (messages.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No messages yet. Say hello!',
                                  style: TextStyle(color: ChatTone.muted),
                                ),
                              );
                            }

                            // Your newest messages the other person has not
                            // opened yet (only known in private chats).
                            final unreadMine = <String>{};
                            if (otherId != null && otherUnread > 0) {
                              for (final m in messages) {
                                if (unreadMine.length >= otherUnread) break;
                                if (m.senderId == currentUserId) {
                                  unreadMine.add(m.id);
                                }
                              }
                            }

                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                final isMe = message.senderId == currentUserId;
                                // Newest first: the day label sits above the
                                // oldest message of each day.
                                final older = index + 1 < messages.length
                                    ? messages[index + 1]
                                    : null;
                                final newDay =
                                    older == null ||
                                    !DateUtils.isSameDay(
                                      older.timestamp,
                                      message.timestamp,
                                    );
                                return Column(
                                  children: [
                                    if (newDay)
                                      _DayChip(date: message.timestamp),
                                    _MessageBubble(
                                      message: message,
                                      isMe: isMe,
                                      showName: room.isGroup && !isMe,
                                      read: isMe && otherId != null
                                          ? !unreadMine.contains(message.id)
                                          : null,
                                      bubblePreset: bubblePreset,
                                      accent: accent,
                                      bubbleStyle: room.bubbleStyle,
                                      textScale: textScale,
                                      mapTilerKey: _mapTilerKey,
                                      onOptions: () =>
                                          _showMessageOptions(message, isMe),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                      _MessageInput(
                        controller: _messageController,
                        onSend: _sendMessage,
                        onMediaPressed: () => _showMediaOptions(context),
                        onMicPressed: _openVoiceRecorder,
                        header: _buildComposerBanner(),
                        editing: _editingMessage != null,
                        accent: accent ?? ChatTone.accent,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.isGroup,
    required this.subtitle,
    required this.online,
    required this.onSettings,
  });

  final String title;
  final bool isGroup;
  final String? subtitle;
  final bool online;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ChatTone.header,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C1D95).withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        4,
        MediaQuery.paddingOf(context).top + 6,
        4,
        10,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: ChatTone.text,
              size: 26,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: ChatTone.avatar,
                child: isGroup
                    ? const Icon(Icons.groups_rounded, color: ChatTone.accent)
                    : Text(
                        title.isEmpty ? '?' : title[0].toUpperCase(),
                        style: const TextStyle(
                          color: ChatTone.accent,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (online)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: ChatTone.online,
                      shape: BoxShape.circle,
                      border: Border.all(color: ChatTone.header, width: 2.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ChatTone.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: ChatTone.muted,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Chat settings',
            onPressed: onSettings,
            icon: const Icon(Icons.more_vert_rounded, color: ChatTone.text),
          ),
        ],
      ),
    );
  }
}

class _VacationBanner extends StatelessWidget {
  const _VacationBanner({required this.watch, required this.onTap});
  final VacationWatch watch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dates =
        '${DateFormat('MMM d').format(watch.startDate)} – '
        '${DateFormat('MMM d').format(watch.endDate)}';
    final place = watch.address.split(',').take(2).join(',').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: const Color(0x224C1D95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ChatTone.otherBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: ChatTone.avatar,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_outlined,
                    color: ChatTone.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vacation Watch',
                        style: TextStyle(
                          color: ChatTone.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        place.isEmpty ? dates : '$dates · $place',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ChatTone.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: ChatTone.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date});
  final DateTime date;

  String get _label {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Today';
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat(
      date.year == now.year ? 'EEE, MMM d' : 'MMM d, y',
    ).format(date);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: ChatTone.chip,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _label,
        style: const TextStyle(color: ChatTone.muted, fontSize: 12.5),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.accent,
    required this.bubbleStyle,
    required this.textScale,
    required this.message,
    required this.isMe,
    required this.showName,
    required this.read,
    required this.bubblePreset,
    required this.mapTilerKey,
    required this.onOptions,
  });

  final ChatMessage message;
  final bool isMe;
  final bool showName;

  /// For your own messages in a private chat: whether the other person has
  /// opened it. Null when unknown.
  final bool? read;
  final ChatBubblePreset bubblePreset;
  final String mapTilerKey;
  final VoidCallback onOptions;

  /// Custom colour for your messages, if one was picked in Chat settings.
  final Color? accent;

  /// 'rounded', 'pill', 'square' or 'outline'.
  final String bubbleStyle;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final outline = bubbleStyle == 'outline';
    final selfColor = accent ?? bubblePreset.selfColor;
    final fg = outline
        ? ChatTone.text
        : isMe
        ? bubblePreset.selfTextColor
        : bubblePreset.otherTextColor;
    final meta = fg.withValues(alpha: .7);

    final Widget content = switch (message.type) {
      MessageType.image => _ChatPhoto(url: message.mediaUrl ?? ''),
      MessageType.location => _LocationMessageMap(
        latitude: message.latitude ?? 0,
        longitude: message.longitude ?? 0,
        mapTilerKey: mapTilerKey,
      ),
      MessageType.voice => _VoiceNotePlayer(
        source: message.mediaUrl ?? '',
        isMe: isMe,
        bubblePreset: bubblePreset,
      ),
      _ => Text(
        message.content,
        style: TextStyle(color: fg, fontSize: 15 * textScale, height: 1.35),
      ),
    };

    final radius = switch (bubbleStyle) {
      'pill' => BorderRadius.circular(26),
      'square' => BorderRadius.circular(6),
      _ => BorderRadius.circular(20).copyWith(
        bottomRight: isMe ? const Radius.circular(6) : null,
        bottomLeft: isMe ? null : const Radius.circular(6),
      ),
    };
    final useGradient = isMe && !outline;
    final gradientColors = accent == null
        ? (bubblePreset.usesGradient ? ChatTone.selfGradient : null)
        : [Color.lerp(accent, Colors.white, .12)!, accent!];

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
      decoration: BoxDecoration(
        color: outline
            ? Colors.white
            : isMe
            ? (gradientColors == null ? selfColor : null)
            : bubblePreset.otherColor,
        gradient: useGradient && gradientColors != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              )
            : null,
        borderRadius: radius,
        border: outline
            ? Border.all(
                color: isMe ? selfColor : ChatTone.otherBorder,
                width: 1.5,
              )
            : isMe
            ? null
            : Border.all(color: ChatTone.otherBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                message.senderName,
                style: const TextStyle(
                  color: ChatTone.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if ((message.replyPreview ?? '').trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white.withValues(alpha: .16)
                    : ChatTone.accent.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: fg.withValues(alpha: .6), width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.replySenderName ?? 'Reply',
                    style: TextStyle(
                      color: fg,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    message.replyPreview!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: meta, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          content,
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.editedAt != null) ...[
                  Text(
                    'edited',
                    style: TextStyle(
                      color: meta,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: TextStyle(color: meta, fontSize: 11),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    read == false ? Icons.done_rounded : Icons.done_all_rounded,
                    size: 15,
                    color: read == true
                        ? (outline ? selfColor : Colors.white)
                        : meta,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final sender = message.senderName.trim();
    final optionsButton = SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        tooltip: isMe && message.type == MessageType.text
            ? 'Reply or edit'
            : 'Reply',
        padding: EdgeInsets.zero,
        iconSize: 18,
        color: ChatTone.muted,
        onPressed: onOptions,
        icon: const Icon(Icons.more_vert_rounded),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 17,
              backgroundColor: ChatTone.avatar,
              child: Text(
                sender.isEmpty ? '?' : sender[0].toUpperCase(),
                style: const TextStyle(
                  color: ChatTone.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (isMe) optionsButton,
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .70,
              ),
              child: Semantics(
                hint: 'Long press for reply and other options',
                customSemanticsActions: {
                  const CustomSemanticsAction(label: 'Message options'):
                      onOptions,
                },
                child: GestureDetector(onLongPress: onOptions, child: bubble),
              ),
            ),
          ),
          if (!isMe) optionsButton,
        ],
      ),
    );
  }
}

class _LocationMessageMap extends StatelessWidget {
  const _LocationMessageMap({
    required this.latitude,
    required this.longitude,
    required this.mapTilerKey,
  });

  final double latitude;
  final double longitude;
  final String mapTilerKey;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 220,
        height: 150,
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(initialCenter: point, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}',
                additionalOptions: {'key': mapTilerKey},
                userAgentPackageName: 'com.example.community',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.location_pin,
                      color: AppColors.alert,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceNotePlayer extends StatefulWidget {
  const _VoiceNotePlayer({
    required this.source,
    required this.isMe,
    required this.bubblePreset,
  });

  final String source;
  final bool isMe;
  final ChatBubblePreset bubblePreset;

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  late final ap.AudioPlayer _audioPlayer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completionSubscription;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop);
    unawaited(_audioPlayer.setSource(_source));
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    _completionSubscription = _audioPlayer.onPlayerComplete.listen((_) async {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  ap.Source get _source => widget.source.startsWith('http')
      ? ap.UrlSource(widget.source)
      : ap.DeviceFileSource(widget.source);

  Future<void> _togglePlayback() async {
    if (_audioPlayer.state == ap.PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
      if (_audioPlayer.state != ap.PlayerState.playing) {
        await _audioPlayer.play(_source);
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor = widget.isMe
        ? widget.bubblePreset.selfTextColor
        : widget.bubblePreset.otherTextColor;
    final accentColor = foregroundColor;
    final maxMillis = _duration.inMilliseconds <= 0
        ? 1
        : _duration.inMilliseconds;
    final currentMillis = _position.inMilliseconds.clamp(0, maxMillis);

    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _togglePlayback,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _audioPlayer.state == ap.PlayerState.playing
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Voice note',
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: accentColor,
              inactiveTrackColor: foregroundColor.withValues(alpha: 0.2),
              thumbColor: accentColor,
            ),
            child: Slider(
              value: currentMillis.toDouble(),
              max: maxMillis.toDouble(),
              onChanged: (value) async {
                await _audioPlayer.seek(Duration(milliseconds: value.round()));
                if (!mounted) return;
                setState(() {
                  _position = Duration(milliseconds: value.round());
                });
              },
            ),
          ),
          Text(
            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
            style: TextStyle(
              fontSize: 11,
              color: foregroundColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceNoteRecorderSheet extends StatefulWidget {
  const _VoiceNoteRecorderSheet({required this.onSend});

  final Future<void> Function(String path) onSend;

  @override
  State<_VoiceNoteRecorderSheet> createState() =>
      _VoiceNoteRecorderSheetState();
}

class _VoiceNoteRecorderSheetState extends State<_VoiceNoteRecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSending = false;
  String? _recordedPath;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<String> _buildRecordingPath() async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/voice_note_$timestamp.m4a';
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice notes.'),
        ),
      );
      return;
    }

    final path = await _buildRecordingPath();
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
        sampleRate: 44100,
        bitRate: 128000,
      ),
      path: path,
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordedPath = null;
      _elapsed = Duration.zero;
    });
  }

  String _formatElapsed(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _send() async {
    final path = _recordedPath;
    if (path == null || path.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await widget.onSend(path);
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voice note', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              _isRecording
                  ? 'Recording... ${_formatElapsed(_elapsed)}'
                  : (_recordedPath != null
                        ? 'Voice note ready to send'
                        : 'Tap the mic to start recording'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _isSending ? null : _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? colorScheme.error : colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isRecording
                                  ? colorScheme.error
                                  : colorScheme.primary)
                              .withValues(alpha: 0.28),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            if (_recordedPath != null) ...[
              const SizedBox(height: 20),
              _VoiceNotePlayer(
                source: _recordedPath!,
                isMe: false,
                bubblePreset: ChatAppearanceCatalog.bubbleThemes.first,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSending
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        (_recordedPath == null || _isRecording || _isSending)
                        ? null
                        : _send,
                    child: _isSending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.onMediaPressed,
    required this.onMicPressed,
    required this.editing,
    required this.accent,
    this.header,
  });

  final Color accent;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMediaPressed;
  final VoidCallback onMicPressed;
  final bool editing;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 8)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: ChatTone.composer,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: ChatTone.otherBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Attach photo or location',
                        onPressed: onMediaPressed,
                        style: IconButton.styleFrom(
                          backgroundColor: ChatTone.avatar,
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(
                          Icons.add_rounded,
                          color: ChatTone.accent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            color: ChatTone.text,
                            fontSize: 15,
                          ),
                          cursorColor: ChatTone.accent,
                          decoration: InputDecoration(
                            hintText: 'Type a message…',
                            hintStyle: const TextStyle(color: ChatTone.muted),
                            filled: true,
                            fillColor: ChatTone.field,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: const BorderSide(
                                color: ChatTone.accent,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => onSend(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Mic when the box is empty; send once there is text.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final send = editing || value.text.trim().isNotEmpty;
                  return IconButton(
                    tooltip: send
                        ? (editing ? 'Save edit' : 'Send')
                        : 'Record voice note',
                    onPressed: send ? onSend : onMicPressed,
                    style: IconButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(56, 56),
                    ),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        send
                            ? (editing
                                  ? Icons.check_rounded
                                  : Icons.send_rounded)
                            : Icons.mic_none_rounded,
                        key: ValueKey(send ? (editing ? 'e' : 's') : 'm'),
                        size: 26,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerBanner extends StatelessWidget {
  const _ComposerBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: ChatTone.field,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: ChatTone.accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ChatTone.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ChatTone.accent,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ChatTone.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.close_rounded, color: ChatTone.muted),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// A photo in the chat. With auto-download off (Chat settings) it waits for
/// a tap before loading.
class _ChatPhoto extends StatefulWidget {
  const _ChatPhoto({required this.url});
  final String url;

  @override
  State<_ChatPhoto> createState() => _ChatPhotoState();
}

class _ChatPhotoState extends State<_ChatPhoto> {
  late bool _show = UiPreferences.instance.autoDownloadMedia;

  @override
  Widget build(BuildContext context) {
    if (!_show) {
      return Material(
        color: ChatTone.field,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _show = true),
          child: const SizedBox(
            width: 220,
            height: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_rounded, color: ChatTone.accent),
                SizedBox(height: 4),
                Text(
                  'Tap to load photo',
                  style: TextStyle(color: ChatTone.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        widget.url,
        height: 200,
        width: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox(
          height: 120,
          width: 220,
          child: Icon(Icons.broken_image_outlined, color: ChatTone.muted),
        ),
      ),
    );
  }
}
