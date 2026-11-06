import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../services/auth_service.dart';
import '../services/live_value.dart';
import '../services/ui_preferences.dart';
import '../theme/chat_appearance.dart';
import '../theme/home_tone.dart';
import '../widgets/hero_header.dart';
import '../widgets/overlap_header.dart';

enum _Section { colors, wallpaper, bubbles, font, more }

/// Your chat profile, how this chat looks, and chat preferences.
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
  static const Color _defaultAccent = Color(0xFF7A3DF2);
  static const List<Color> _quickPicks = [
    Color(0xFF7A3DF2),
    Color(0xFF2563EB),
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
    Color(0xFF22C55E),
    Color(0xFF84CC16),
    Color(0xFFEAB308),
    Color(0xFFF59E0B),
    Color(0xFFF97316),
    Color(0xFFF43F5E),
  ];

  final _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isSavingName = false;
  XFile? _profilePreview;

  _Section _section = _Section.colors;
  late String _backgroundKey = widget.chatRoom.backgroundKey;
  late String _bubbleThemeKey = widget.chatRoom.bubbleThemeKey;
  late Color? _accent = widget.chatRoom.accentColor == null
      ? null
      : Color(widget.chatRoom.accentColor!);
  late String _bubbleStyle = widget.chatRoom.bubbleStyle;
  late String _textSize = widget.chatRoom.textSize;
  late bool _pinned = widget.chatRoom.isPinnedBy(_userId);

  late final LiveValue<QuerySnapshot<Map<String, dynamic>>> _users = LiveValue(
    widget.chatRepository.getUsersStream(),
  );
  late final LiveValue<List<ChatRoom>> _rooms = LiveValue(
    widget.chatRepository.getChatRooms(_userId),
  );

  String get _userId => widget.authService.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    final user = widget.authService.currentUser;
    _nameController.text = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? '');
  }

  @override
  void dispose() {
    _users.close();
    _rooms.close();
    _nameController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------------------------------------------- saving

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
      _showMessage('Chat name saved');
    } catch (error) {
      _showMessage('Could not save your name: $error');
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _profilePreview = file);
    _showMessage(
      'Photo shown here only. Profile photos can be saved once photo '
      'uploads are set up.',
    );
  }

  /// Saves one appearance change for this chat.
  Future<void> _saveAppearance({
    String? backgroundKey,
    String? bubbleThemeKey,
    Color? accent,
    bool clearAccent = false,
    String? bubbleStyle,
    String? textSize,
  }) async {
    try {
      await widget.chatRepository.updateChatAppearance(
        chatRoomId: widget.chatRoom.id,
        backgroundKey: backgroundKey,
        bubbleThemeKey: bubbleThemeKey,
        accentColor: accent?.toARGB32(),
        clearAccentColor: clearAccent,
        bubbleStyle: bubbleStyle,
        textSize: textSize,
      );
    } catch (error) {
      _showMessage('Could not save that change: $error');
    }
  }

  void _setAccent(Color? color, {bool save = true}) {
    setState(() => _accent = color);
    if (!save) return;
    if (color == null) {
      _saveAppearance(clearAccent: true);
    } else {
      _saveAppearance(accent: color);
    }
  }

  Future<void> _setPinned(bool value) async {
    setState(() => _pinned = value);
    try {
      await widget.chatRepository.setPinned(
        chatRoomId: widget.chatRoom.id,
        userId: _userId,
        pinned: value,
      );
    } catch (error) {
      if (mounted) setState(() => _pinned = !value);
      _showMessage('Could not update: $error');
    }
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: PinnedHeader(
          overlap: 28,
          header: const PageHeroHeader(
            title: 'Chat Settings',
            subtitle: 'Personalize your chat experience.',
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _profileCard(),
                    const SizedBox(height: 12),
                    _appearanceCard(),
                    const SizedBox(height: 12),
                    _preferencesCard(),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard() {
    final user = widget.authService.currentUser;
    final name = _nameController.text.trim();
    final preview = _profilePreview;
    final ImageProvider? photo = preview == null
        ? null
        : kIsWeb
        ? NetworkImage(preview.path)
        : FileImage(File(preview.path));

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: HomeTone.violetDim,
                    backgroundImage: photo,
                    child: photo != null
                        ? null
                        : Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: const TextStyle(
                              color: HomeTone.violet,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      color: HomeTone.violet,
                      shape: const CircleBorder(
                        side: BorderSide(color: Colors.white, width: 2),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickPhoto,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 16,
                            color: Colors.white,
                            semanticLabel: 'Change photo',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Profile',
                      style: TextStyle(
                        color: HomeTone.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'This is how others see you in chats.',
                      style: TextStyle(color: HomeTone.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FieldShell(
            icon: Icons.person_outline_rounded,
            child: TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: HomeTone.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              cursorColor: HomeTone.violet,
              decoration: const InputDecoration(
                labelText: 'Chat name',
                labelStyle: TextStyle(color: HomeTone.muted),
                floatingLabelStyle: TextStyle(color: HomeTone.violet),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          if ((user?.email ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _FieldShell(
              icon: Icons.mail_outline_rounded,
              child: Text(
                user!.email!.trim(),
                style: const TextStyle(color: HomeTone.ink, fontSize: 14),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _isSavingName || _userId.isEmpty
                      ? null
                      : _saveDisplayName,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeTone.violet,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: const StadiumBorder(),
                  ),
                  child: _isSavingName
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeTone.violet,
                    minimumSize: const Size(0, 46),
                    side: const BorderSide(color: HomeTone.violetDim, width: 2),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined, size: 19),
                  label: const Text('Change Photo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appearanceCard() {
    const sections = [
      (_Section.colors, Icons.brush_outlined, 'Colors'),
      (_Section.wallpaper, Icons.wallpaper_outlined, 'Wallpaper'),
      (_Section.bubbles, Icons.chat_bubble_outline_rounded, 'Chat Bubbles'),
      (_Section.font, Icons.text_fields_rounded, 'Font & Text'),
      (_Section.more, Icons.more_horiz_rounded, 'More'),
    ];

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey(_section),
        child: switch (_section) {
          _Section.colors => _colorsSection(),
          _Section.wallpaper => _wallpaperSection(),
          _Section.bubbles => _bubblesSection(),
          _Section.font => _fontSection(),
          _Section.more => _moreSection(),
        },
      ),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(
            icon: Icons.palette_outlined,
            title: 'Chat Appearance',
            subtitle: 'Applies to this chat, for everyone in it.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 560;
              Widget navItem((_Section, IconData, String) entry) {
                final (section, icon, label) = entry;
                final selected = _section == section;
                return Semantics(
                  button: true,
                  selected: selected,
                  child: Material(
                    color: selected ? HomeTone.violetDim : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _section = section),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: wide
                              ? MainAxisSize.max
                              : MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: selected ? HomeTone.violet : HomeTone.ink,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? HomeTone.violet
                                    : HomeTone.ink,
                                fontSize: 13.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 170,
                      child: Column(
                        children: [
                          for (final entry in sections) ...[
                            navItem(entry),
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 320,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: HomeTone.border,
                    ),
                    Expanded(child: content),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in sections) ...[
                          navItem(entry),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 20, color: HomeTone.border),
                  content,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _colorsSection() {
    final current = _accent ?? _defaultAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          'Accent color',
          'Choose any color for your messages and highlights.',
        ),
        const SizedBox(height: 10),
        _HsvPicker(
          color: current,
          onChanged: (c) => _setAccent(c, save: false),
          onChangeEnd: (c) => _setAccent(c),
        ),
        const SizedBox(height: 14),
        const Text(
          'Quick picks',
          style: TextStyle(
            color: HomeTone.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in _quickPicks)
              _Swatch(
                color: color,
                selected: current.toARGB32() == color.toARGB32(),
                onTap: () => _setAccent(color),
              ),
            Tooltip(
              message: 'Use the bubble theme colour',
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(
                  side: BorderSide(color: HomeTone.border, width: 1.5),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _setAccent(null),
                  child: const SizedBox.square(
                    dimension: 36,
                    child: Icon(
                      Icons.restart_alt_rounded,
                      color: HomeTone.ink,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Message bubble style',
          style: TextStyle(
            color: HomeTone.ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (key, label) in const [
              ('rounded', 'Rounded'),
              ('pill', 'Pill'),
              ('square', 'Square'),
              ('outline', 'Outline'),
            ]) ...[
              Expanded(
                child: _BubbleStyleOption(
                  styleKey: key,
                  label: label,
                  color: current,
                  selected: _bubbleStyle == key,
                  onTap: () {
                    setState(() => _bubbleStyle = key);
                    _saveAppearance(bubbleStyle: key);
                  },
                ),
              ),
              if (key != 'outline') const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }

  Widget _wallpaperSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionLabel('Wallpaper', 'The background behind the messages.'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final preset in ChatAppearanceCatalog.backgrounds)
            _PresetTile(
              label: preset.label,
              selected: _backgroundKey == preset.key,
              onTap: () {
                setState(() => _backgroundKey = preset.key);
                _saveAppearance(backgroundKey: preset.key);
              },
              preview: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: preset.colors,
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _bubblesSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionLabel(
        'Chat bubbles',
        'Colour pairs for your messages and theirs. A custom accent colour '
            'replaces your colour.',
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final preset in ChatAppearanceCatalog.bubbleThemes)
            _PresetTile(
              label: preset.label,
              selected: _bubbleThemeKey == preset.key,
              onTap: () {
                setState(() => _bubbleThemeKey = preset.key);
                _saveAppearance(bubbleThemeKey: preset.key);
              },
              preview: Builder(
                builder: (context) {
                  final p = ChatAppearanceCatalog.chatBubbleByKey(preset.key);
                  Widget bubble(Color c, Alignment a) => Align(
                    alignment: a,
                    child: Container(
                      width: 46,
                      height: 14,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  );
                  return ColoredBox(
                    color: const Color(0xFFFCFBFF),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          bubble(p.otherColor, Alignment.centerLeft),
                          bubble(p.selfColor, Alignment.centerRight),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ],
  );

  Widget _fontSection() {
    final scale = switch (_textSize) {
      'small' => .9,
      'large' => 1.15,
      _ => 1.0,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Font & Text', 'Size of the text in messages.'),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'small', label: Text('Small')),
            ButtonSegment(value: 'default', label: Text('Default')),
            ButtonSegment(value: 'large', label: Text('Large')),
          ],
          selected: {_textSize},
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: HomeTone.violetDim,
            selectedForegroundColor: HomeTone.violet,
            foregroundColor: HomeTone.ink,
            side: const BorderSide(color: HomeTone.border),
          ),
          onSelectionChanged: (value) {
            setState(() => _textSize = value.first);
            _saveAppearance(textSize: value.first);
          },
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _accent ?? _defaultAccent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'This is how your messages look.',
              style: TextStyle(color: Colors.white, fontSize: 15 * scale),
            ),
          ),
        ),
      ],
    );
  }

  Widget _moreSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionLabel('Your chats', 'Open another conversation.'),
      const SizedBox(height: 6),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _users.stream,
        initialData: _users.latest,
        builder: (context, usersSnapshot) {
          final names = <String, String>{
            for (final doc in usersSnapshot.data?.docs ?? const [])
              doc.id: _displayName(doc.data(), doc.id),
          };
          return StreamBuilder<List<ChatRoom>>(
            stream: _rooms.stream,
            initialData: _rooms.latest,
            builder: (context, snapshot) {
              final rooms = snapshot.data ?? const <ChatRoom>[];
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(color: HomeTone.violet),
                );
              }
              if (rooms.isEmpty) {
                return const Text(
                  'No other chats yet.',
                  style: TextStyle(color: HomeTone.muted),
                );
              }
              return Column(
                children: [
                  for (final room in rooms)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: HomeTone.violetDim,
                        child: Icon(
                          room.isGroup
                              ? Icons.groups_rounded
                              : Icons.person_rounded,
                          color: HomeTone.violet,
                        ),
                      ),
                      title: Text(
                        _roomTitle(room, names),
                        style: const TextStyle(
                          color: HomeTone.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        room.lastMessage ?? 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: HomeTone.muted),
                      ),
                      trailing: room.id == widget.chatRoom.id
                          ? const Text(
                              'Current',
                              style: TextStyle(
                                color: HomeTone.violet,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : const Icon(
                              Icons.chevron_right_rounded,
                              color: HomeTone.muted,
                            ),
                      onTap: () => Navigator.pop(context, room),
                    ),
                ],
              );
            },
          );
        },
      ),
    ],
  );

  Widget _preferencesCard() => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CardTitle(
          icon: Icons.settings_outlined,
          title: 'Chat Settings',
          subtitle: 'Control your chat experience.',
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          icon: Icons.push_pin_outlined,
          title: 'Keep chat on top',
          subtitle: 'Pin this conversation in your chat list',
          value: _pinned,
          onChanged: _userId.isEmpty ? null : _setPinned,
        ),
        ListenableBuilder(
          listenable: UiPreferences.instance,
          builder: (context, _) => _ToggleRow(
            icon: Icons.image_outlined,
            title: 'Auto-download media',
            subtitle: 'Load photos straight away in all chats',
            value: UiPreferences.instance.autoDownloadMedia,
            onChanged: UiPreferences.instance.setAutoDownloadMedia,
          ),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------- helpers

  static String _displayName(Map<String, dynamic> data, String fallbackId) {
    final rawName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    if (rawName != null &&
        rawName.isNotEmpty &&
        rawName.toLowerCase() != 'new member') {
      return rawName;
    }
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return fallbackId;
  }

  String _roomTitle(ChatRoom room, Map<String, String> names) {
    if (room.isGroup) return room.name;
    for (final id in room.participantIds) {
      if (id != _userId) return names[id] ?? room.name;
    }
    return room.name;
  }
}

// ------------------------------------------------------------------ widgets

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: HomeTone.border),
      boxShadow: HomeTone.cardShadow,
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: HomeTone.violet, size: 28),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  color: HomeTone.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: HomeTone.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: HomeTone.ink,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(
        subtitle,
        style: const TextStyle(color: HomeTone.muted, fontSize: 12.5),
      ),
    ],
  );
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    constraints: const BoxConstraints(minHeight: 52),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F4FD),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HomeTone.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: HomeTone.ink, size: 22),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label:
        'Colour #${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: selected
              ? [BoxShadow(color: color, spreadRadius: 2)]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
            : null,
      ),
    ),
  );
}

/// Saturation/brightness square, a hue bar and a hex box.
class _HsvPicker extends StatefulWidget {
  const _HsvPicker({
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
  });
  final Color color;
  final ValueChanged<Color> onChanged;
  final ValueChanged<Color> onChangeEnd;

  @override
  State<_HsvPicker> createState() => _HsvPickerState();
}

class _HsvPickerState extends State<_HsvPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.color);
  late final TextEditingController _hex = TextEditingController(
    text: _hexOf(widget.color),
  );

  static String _hexOf(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  void didUpdateWidget(_HsvPicker old) {
    super.didUpdateWidget(old);
    if (widget.color.toARGB32() != _hsv.toColor().toARGB32()) {
      _hsv = HSVColor.fromColor(widget.color);
      _hex.text = _hexOf(widget.color);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _update(HSVColor hsv, {bool end = false}) {
    setState(() => _hsv = hsv);
    final color = hsv.toColor();
    _hex.text = _hexOf(color);
    end ? widget.onChangeEnd(color) : widget.onChanged(color);
  }

  void _fromHex(String text) {
    final clean = text.replaceAll('#', '').trim();
    if (clean.length != 6) return;
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return;
    _update(HSVColor.fromColor(Color(0xFF000000 | value)), end: true);
  }

  @override
  Widget build(BuildContext context) {
    const height = 150.0;
    final square = LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        void pick(Offset p, {bool end = false}) {
          _update(
            _hsv
                .withSaturation((p.dx / w).clamp(0, 1))
                .withValue(1 - (p.dy / height).clamp(0, 1)),
            end: end,
          );
        }

        return Semantics(
          label: 'Colour saturation and brightness',
          child: GestureDetector(
            onPanDown: (d) => pick(d.localPosition),
            onPanUpdate: (d) => pick(d.localPosition),
            onPanEnd: (_) => widget.onChangeEnd(_hsv.toColor()),
            child: SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Color(0x00FFFFFF)],
                          ),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Colors.black],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _hsv.saturation * w - 10,
                      top: (1 - _hsv.value) * height - 10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: Color(0x55000000), blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    void pickHue(Offset p, {bool end = false}) =>
        _update(_hsv.withHue((p.dy / height).clamp(0, 1) * 359.9), end: end);

    final hueBar = Semantics(
      label: 'Hue',
      child: GestureDetector(
        onPanDown: (d) => pickHue(d.localPosition),
        onPanUpdate: (d) => pickHue(d.localPosition),
        onPanEnd: (_) => widget.onChangeEnd(_hsv.toColor()),
        child: SizedBox(
          width: 22,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        for (var h = 0; h <= 360; h += 60)
                          HSVColor.fromAHSV(
                            1,
                            h.toDouble() % 360,
                            1,
                            1,
                          ).toColor(),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -1,
                top: _hsv.hue / 360 * height - 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x55000000), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final side = Column(
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: _hsv.toColor(),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _hex,
          textAlign: TextAlign.center,
          maxLength: 7,
          style: const TextStyle(
            color: HomeTone.ink,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: HomeTone.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: HomeTone.border),
            ),
          ),
          onSubmitted: _fromHex,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 360) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: square),
              const SizedBox(width: 12),
              hueBar,
              const SizedBox(width: 12),
              SizedBox(width: 96, child: side),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: square),
                const SizedBox(width: 12),
                hueBar,
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: _hsv.toColor(),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 110, child: side.children.last),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BubbleStyleOption extends StatelessWidget {
  const _BubbleStyleOption({
    required this.styleKey,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String styleKey;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = switch (styleKey) {
      'pill' => BorderRadius.circular(14),
      'square' => BorderRadius.circular(3),
      _ => BorderRadius.circular(
        10,
      ).copyWith(bottomLeft: const Radius.circular(3)),
    };
    final outline = styleKey == 'outline';
    return Semantics(
      button: true,
      selected: selected,
      label: '$label bubbles',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 56,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? HomeTone.violetDim : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? HomeTone.violet : HomeTone.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Container(
                  height: 26,
                  decoration: BoxDecoration(
                    color: outline ? Colors.white : color.withValues(alpha: .6),
                    borderRadius: radius,
                    border: outline
                        ? Border.all(color: color, width: 1.5)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? HomeTone.violet : HomeTone.ink,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.preview,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? HomeTone.violet : HomeTone.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview,
                  if (selected)
                    const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: HomeTone.violet,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? HomeTone.violet : HomeTone.ink,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      // The whole row toggles, not just the switch.
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: HomeTone.violet, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: HomeTone.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: HomeTone.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: HomeTone.violet,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: HomeTone.border,
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
