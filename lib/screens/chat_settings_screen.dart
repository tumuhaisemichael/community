import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../services/auth_service.dart';
import '../theme/chat_appearance.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({
    super.key,
    required this.authService,
    required this.chatRepository,
    required this.chatRoom,
  });

  final AuthService authService;
  final ChatRepository chatRepository;
  final ChatRoom chatRoom;

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isSavingName = false;
  String _selectedBackgroundKey = defaultChatBackgroundKey;
  String _selectedBubbleThemeKey = defaultChatBubbleThemeKey;
  XFile? _profilePreview;

  @override
  void initState() {
    super.initState();
    final user = widget.authService.currentUser;
    _nameController.text = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? '');
    _selectedBackgroundKey = widget.chatRoom.backgroundKey;
    _selectedBubbleThemeKey = widget.chatRoom.bubbleThemeKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  Future<void> _saveDisplayName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSavingName = true);

    try {
      final user = widget.authService.currentUser;
      await user?.updateDisplayName(name);
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': name,
          'email': user.email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Username updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update username: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingName = false);
      }
    }
  }

  Future<void> _pickProfilePlaceholder() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    setState(() {
      _profilePreview = file;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Profile photo placeholder added here. We still need image uploads to save it for real.',
        ),
      ),
    );
  }

  Future<void> _saveAppearance() async {
    try {
      await widget.chatRepository.updateChatAppearance(
        chatRoomId: widget.chatRoom.id,
        backgroundKey: _selectedBackgroundKey,
        bubbleThemeKey: _selectedBubbleThemeKey,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat appearance updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update appearance: $error')),
      );
    }
  }

  ImageProvider? _profilePreviewProvider() {
    final preview = _profilePreview;
    if (preview == null) return null;
    if (kIsWeb) {
      return NetworkImage(preview.path);
    }
    return FileImage(File(preview.path));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.authService.currentUser;
    final currentUserId = currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundImage: _profilePreviewProvider(),
                          child: _profilePreview == null
                              ? const Icon(Icons.person, size: 34)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Your username',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              if (currentUser?.email?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 8),
                                Text(
                                  currentUser!.email!.trim(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton(
                                    onPressed: _isSavingName
                                        ? null
                                        : _saveDisplayName,
                                    child: _isSavingName
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Save Name'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickProfilePlaceholder,
                                    icon: const Icon(Icons.add_a_photo),
                                    label: const Text('Add Photo'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (currentUserId.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Sign in to update your chat profile and settings.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chat Appearance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text('Background'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ChatAppearanceCatalog.backgrounds
                          .map(
                            (preset) => ChoiceChip(
                              label: Text(preset.label),
                              selected: _selectedBackgroundKey == preset.key,
                              onSelected: (_) {
                                setState(() {
                                  _selectedBackgroundKey = preset.key;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Chat bubble colors'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ChatAppearanceCatalog.bubbleThemes
                          .map(
                            (preset) => ChoiceChip(
                              label: Text(preset.label),
                              selected: _selectedBubbleThemeKey == preset.key,
                              onSelected: (_) {
                                setState(() {
                                  _selectedBubbleThemeKey = preset.key;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _saveAppearance,
                        child: const Text('Apply Theme'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Chats',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (currentUserId.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Sign in to load your chats.'),
                      )
                    else
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: widget.chatRepository.getUsersStream(),
                        builder: (context, usersSnapshot) {
                          if (usersSnapshot.hasError) {
                            return Text(
                              'Could not load members: ${usersSnapshot.error}',
                            );
                          }

                          final userNames = <String, String>{
                            for (final doc
                                in usersSnapshot.data?.docs ?? const [])
                              doc.id: _preferredDisplayName(doc.data(), doc.id),
                          };

                          return StreamBuilder<List<ChatRoom>>(
                            stream: widget.chatRepository.getChatRooms(
                              currentUserId,
                            ),
                            builder: (context, roomsSnapshot) {
                              if (roomsSnapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !roomsSnapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (roomsSnapshot.hasError) {
                                return Text(
                                  'Could not load chats: ${roomsSnapshot.error}',
                                );
                              }

                              final rooms = roomsSnapshot.data ?? [];

                              if (rooms.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text('No chats yet.'),
                                );
                              }

                              return Column(
                                children: rooms.map((room) {
                                  final title = _resolveRoomTitle(
                                    room,
                                    currentUserId,
                                    userNames,
                                  );
                                  final isCurrentRoom =
                                      room.id == widget.chatRoom.id;

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      child: Icon(
                                        room.isGroup
                                            ? Icons.groups
                                            : Icons.person,
                                      ),
                                    ),
                                    title: Text(title),
                                    subtitle: Text(
                                      room.lastMessage ?? 'No messages yet',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: isCurrentRoom
                                        ? const Text('Open')
                                        : const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.pop(context, room),
                                  );
                                }).toList(),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
