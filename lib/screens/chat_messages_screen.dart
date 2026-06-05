import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = widget.authService.currentUser;
    final message = ChatMessage(
      id: '',
      senderId: user?.uid ?? '',
      senderName: user?.displayName ?? user?.email ?? 'Member',
      content: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    widget.chatRepository.sendMessage(widget.chatRoom.id, message);
    _messageController.clear();
  }

  Future<void> _sendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final urls = await widget.storageService.uploadImages([image]);
    if (urls.isEmpty) return;

    final user = widget.authService.currentUser;
    final message = ChatMessage(
      id: '',
      senderId: user?.uid ?? '',
      senderName: user?.displayName ?? user?.email ?? 'Member',
      content: 'Shared a photo',
      type: MessageType.image,
      timestamp: DateTime.now(),
      mediaUrl: urls.first,
    );

    widget.chatRepository.sendMessage(widget.chatRoom.id, message);
  }

  Future<void> _sendLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final user = widget.authService.currentUser;
      final message = ChatMessage(
        id: '',
        senderId: user?.uid ?? '',
        senderName: user?.displayName ?? user?.email ?? 'Member',
        content: 'Shared location',
        type: MessageType.location,
        timestamp: DateTime.now(),
        latitude: position.latitude,
        longitude: position.longitude,
      );

      widget.chatRepository.sendMessage(widget.chatRoom.id, message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
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
                // Feature #17: Voice notes
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(widget.chatRoom.name)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: widget.chatRepository.getMessages(widget.chatRoom.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    return _MessageBubble(message: message, isMe: isMe);
                  },
                );
              },
            ),
          ),
          _MessageInput(
            controller: _messageController,
            onSend: _sendMessage,
            onMediaPressed: () => _showMediaOptions(context),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget content;
    switch (message.type) {
      case MessageType.image:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                message.mediaUrl!,
                height: 200,
                width: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
          ],
        );
        break;
      case MessageType.location:
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 16),
            const SizedBox(width: 4),
            Text('Location: ${message.latitude?.toStringAsFixed(3)}, ${message.longitude?.toStringAsFixed(3)}'),
          ],
        );
        break;
      default:
        content = Text(
          message.content,
          style: TextStyle(
            color: isMe ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
        );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? colorScheme.primary : colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : null,
            bottomLeft: !isMe ? const Radius.circular(0) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            content,
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: (isMe ? colorScheme.onPrimary : colorScheme.onSurfaceVariant)
                    .withOpacity(0.7),
              ),
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
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMediaPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Row(
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
              icon: const Icon(Icons.send),
              onPressed: onSend,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
