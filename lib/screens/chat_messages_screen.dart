import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

enum _MessageAction { reply, edit }

class ChatMessagesScreen extends StatefulWidget {
  ChatMessagesScreen({
    super.key,
    required this.authService,
    required this.chatRepository,
    required this.chatRoom,
  }) : storageService = StorageService();

  final AuthService authService;
  final ChatRepository chatRepository;
  final ChatRoom chatRoom;
  final StorageService storageService;

  @override
  State<ChatMessagesScreen> createState() => _ChatMessagesScreenState();
}

class _ChatMessagesScreenState extends State<ChatMessagesScreen> {
  final _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late final Stream<List<ChatMessage>> _messagesStream;
  StreamSubscription<List<ChatMessage>>? _readReceiptSubscription;
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;

  @override
  void initState() {
    super.initState();
    _messagesStream = widget.chatRepository.getMessages(widget.chatRoom.id);
    _startReadReceipts();
  }

  @override
  void dispose() {
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

  String _resolveRoomTitle(Map<String, String> userNames) {
    if (widget.chatRoom.isGroup) {
      return widget.chatRoom.name;
    }

    final currentUserId = widget.authService.currentUser?.uid ?? '';
    final otherUserId = widget.chatRoom.participantIds
        .where((participantId) => participantId != currentUserId)
        .cast<String?>()
        .firstWhere(
          (participantId) => participantId != null,
          orElse: () => null,
        );

    if (otherUserId == null) {
      return widget.chatRoom.name;
    }

    return userNames[otherUserId] ?? widget.chatRoom.name;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $error')),
        );
      }
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Send Photo'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Send Location'),
              onTap: () {
                Navigator.pop(context);
                _sendLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Send Voice Note'),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: this.context,
                  isScrollControlled: true,
                  builder: (context) =>
                      _VoiceNoteRecorderSheet(onSend: _sendVoiceNote),
                );
              },
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.authService.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.chatRepository.getUsersStream(),
      builder: (context, usersSnapshot) {
        final userNames = <String, String>{
          for (final doc in usersSnapshot.data?.docs ?? const [])
            doc.id: _preferredDisplayName(doc.data(), doc.id),
        };
        final roomTitle = _resolveRoomTitle(userNames);

        return Scaffold(
          appBar: AppBar(title: Text(roomTitle)),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load messages: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUserId;

                        return _MessageBubble(
                          message: message,
                          isMe: isMe,
                          onActionSelected: (action) =>
                              _handleMessageAction(action, message),
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
                header: _buildComposerBanner(),
                sendIcon: _editingMessage != null ? Icons.check : Icons.send,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onActionSelected,
  });

  final ChatMessage message;
  final bool isMe;
  final ValueChanged<_MessageAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = isMe
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    Widget content;
    switch (message.type) {
      case MessageType.image:
        content = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.mediaUrl!,
            height: 200,
            width: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) =>
                const Icon(Icons.broken_image),
          ),
        );
        break;
      case MessageType.location:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 16),
            const SizedBox(width: 4),
            Text(
              'Location: ${message.latitude?.toStringAsFixed(3)}, ${message.longitude?.toStringAsFixed(3)}',
            ),
          ],
        );
        break;
      case MessageType.voice:
        content = _VoiceNotePlayer(source: message.mediaUrl ?? '', isMe: isMe);
        break;
      default:
        content = Text(
          message.content,
          style: TextStyle(color: foregroundColor),
        );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : null,
            bottomLeft: !isMe ? const Radius.circular(0) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Text(
                          message.senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: foregroundColor,
                          ),
                        ),
                      if (message.replyPreview != null &&
                          message.replyPreview!.trim().isNotEmpty) ...[
                        if (!isMe) const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isMe
                                ? colorScheme.onPrimary.withValues(alpha: 0.12)
                                : colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.replySenderName ?? 'Reply',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isMe
                                      ? colorScheme.onPrimary
                                      : colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message.replyPreview!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isMe
                                      ? colorScheme.onPrimary.withValues(
                                          alpha: 0.9,
                                        )
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_MessageAction>(
                  tooltip: 'Message options',
                  color: Theme.of(context).colorScheme.surface,
                  icon: Icon(Icons.more_vert, size: 18, color: foregroundColor),
                  onSelected: onActionSelected,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _MessageAction.reply,
                      child: Text('Reply'),
                    ),
                    if (isMe && message.type == MessageType.text)
                      const PopupMenuItem(
                        value: _MessageAction.edit,
                        child: Text('Edit'),
                      ),
                  ],
                ),
              ],
            ),
            if (!isMe && message.replyPreview == null)
              const SizedBox(height: 4),
            content,
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: foregroundColor.withValues(alpha: 0.7),
                  ),
                ),
                if (message.editedAt != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    'edited',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: foregroundColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceNotePlayer extends StatefulWidget {
  const _VoiceNotePlayer({required this.source, required this.isMe});

  final String source;
  final bool isMe;

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
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = widget.isMe
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;
    final accentColor = widget.isMe
        ? colorScheme.onPrimary
        : colorScheme.primary;
    final maxMillis = _duration.inMilliseconds <= 0
        ? 1
        : _duration.inMilliseconds;
    final currentMillis = _position.inMilliseconds.clamp(0, maxMillis);

    return SizedBox(
      width: 220,
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
                    color: accentColor.withValues(
                      alpha: widget.isMe ? 0.14 : 0.12,
                    ),
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
                setState(
                  () => _position = Duration(milliseconds: value.round()),
                );
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
            Text('Voice Note', style: Theme.of(context).textTheme.titleLarge),
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
              _VoiceNotePlayer(source: _recordedPath!, isMe: false),
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
    required this.sendIcon,
    this.header,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMediaPressed;
  final IconData sendIcon;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) ...[header!, const SizedBox(height: 8)],
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onMediaPressed,
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(sendIcon),
                  onPressed: onSend,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
