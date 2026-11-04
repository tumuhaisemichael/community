import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../repositories/chat_repository.dart';
import '../services/auth_service.dart';
import '../services/live_value.dart';
import '../theme/home_tone.dart';
import '../widgets/community_ui.dart';
import '../widgets/hero_header.dart';
import 'chat_messages_screen.dart';

/// One member as shown in the directory.
class DirectoryMember {
  const DirectoryMember({
    required this.id,
    required this.name,
    this.address,
    this.verified = false,
    this.online = false,
  });

  final String id;
  final String name;
  final String? address;
  final bool verified;
  final bool online;

  static String nameOf(Map<String, dynamic> data) {
    final name = (data['displayName'] as String?)?.trim();
    if (name != null && name.isNotEmpty && name.toLowerCase() != 'new member') {
      return name;
    }
    final email = (data['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Member';
  }

  factory DirectoryMember.fromMap(String id, Map<String, dynamic> data) {
    final updated = data['locationUpdatedAt'];
    final address = (data['address'] as String?)?.trim();
    return DirectoryMember(
      id: id,
      name: nameOf(data),
      address: address == null || address.isEmpty ? null : address,
      verified: data['isVerified'] == true,
      // Same rule as the Map: location shared in the last 15 minutes.
      online:
          updated is Timestamp &&
          DateTime.now().difference(updated.toDate()) <
              const Duration(minutes: 15),
    );
  }
}

enum _MemberFilter { all, verified, online }

/// Everyone in the community, with search and a quick way to message them.
class NeighborDirectoryScreen extends StatefulWidget {
  const NeighborDirectoryScreen({
    super.key,
    this.authService,
    this.chatRepository,
    this.members,
  });

  /// Needed for the Message button; without them it is hidden.
  final AuthService? authService;
  final ChatRepository? chatRepository;

  /// Defaults to the Firestore `users` collection. Tests pass their own.
  final Stream<List<DirectoryMember>>? members;

  @override
  State<NeighborDirectoryScreen> createState() =>
      _NeighborDirectoryScreenState();
}

class _NeighborDirectoryScreenState extends State<NeighborDirectoryScreen> {
  // Opened once: typing in search must not reload the list.
  late final LiveValue<List<DirectoryMember>> _members = LiveValue(
    widget.members ??
        FirebaseFirestore.instance
            .collection('users')
            .snapshots()
            .map(
              (snapshot) => [
                for (final doc in snapshot.docs)
                  DirectoryMember.fromMap(doc.id, doc.data()),
              ],
            ),
  );
  final TextEditingController _search = TextEditingController();
  _MemberFilter _filter = _MemberFilter.all;

  String get _myId => widget.authService?.currentUser?.uid ?? '';

  @override
  void dispose() {
    _members.close();
    _search.dispose();
    super.dispose();
  }

  Future<void> _message(DirectoryMember member) async {
    final auth = widget.authService;
    final chats = widget.chatRepository;
    final me = auth?.currentUser;
    if (auth == null || chats == null || me == null) return;
    try {
      final room = await chats.createOrGetPrivateChat(
        currentUserId: me.uid,
        currentUserName: me.displayName ?? me.email ?? 'Member',
        otherUserId: member.id,
        otherUserName: member.name,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatMessagesScreen(
            authService: auth,
            chatRepository: chats,
            chatRoom: room,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not start chat: $error')));
    }
  }

  void _showMember(DirectoryMember member) {
    final canMessage =
        widget.authService != null &&
        widget.chatRepository != null &&
        member.id != _myId;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: HomeTone.card,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Avatar(member: member, radius: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NameLine(member: member, size: 18),
                        Text(
                          member.online ? 'Online now' : 'Community member',
                          style: TextStyle(
                            color: member.online
                                ? HomeTone.green
                                : HomeTone.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (member.address != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: HomeTone.muted,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        member.address!,
                        style: const TextStyle(color: HomeTone.ink),
                      ),
                    ),
                  ],
                ),
              ],
              if (canMessage) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _message(member);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeTone.violet,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text('Message ${member.name.split(' ').first}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: StreamBuilder<List<DirectoryMember>>(
          stream: _members.stream,
          initialData: _members.latest,
          builder: (context, snapshot) {
            final all = [...?snapshot.data]
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
            final verified = all.where((m) => m.verified).length;
            final online = all.where((m) => m.online).length;
            final query = _search.text.trim().toLowerCase();
            final shown = all.where((m) {
              if (_filter == _MemberFilter.verified && !m.verified) {
                return false;
              }
              if (_filter == _MemberFilter.online && !m.online) return false;
              if (query.isEmpty) return true;
              return m.name.toLowerCase().contains(query) ||
                  (m.address ?? '').toLowerCase().contains(query);
            }).toList();

            return Column(
              children: [
                PageHeroHeader(
                  title: 'Neighbour Directory',
                  subtitle: snapshot.hasData
                      ? '${all.length} members · $verified verified · '
                            '$online online'
                      : 'Members of your community',
                  bottom: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Column(
                      children: [
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                            color: HomeTone.ink,
                            fontSize: 15,
                          ),
                          cursorColor: HomeTone.violet,
                          decoration: InputDecoration(
                            hintText: 'Search by name or area…',
                            hintStyle: const TextStyle(color: HomeTone.muted),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: HomeTone.muted,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1EDFA),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
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
                              borderSide: const BorderSide(
                                color: HomeTone.violet,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final (filter, label, icon) in const [
                                (_MemberFilter.all, 'All', null),
                                (
                                  _MemberFilter.verified,
                                  'Verified',
                                  Icons.verified_outlined,
                                ),
                                (_MemberFilter.online, 'Online', Icons.circle),
                              ]) ...[
                                _Chip(
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
                Expanded(child: _list(snapshot, shown, query)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _list(
    AsyncSnapshot<List<DirectoryMember>> snapshot,
    List<DirectoryMember> shown,
    String query,
  ) {
    if (snapshot.hasError) {
      return const _Message(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load neighbours',
        message: 'Check your connection and try again.',
      );
    }
    if (!snapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SkeletonList(count: 5),
      );
    }
    if (shown.isEmpty) {
      return _Message(
        icon: Icons.groups_outlined,
        title: snapshot.data!.isEmpty ? 'No neighbours yet' : 'No one found',
        message: snapshot.data!.isEmpty
            ? 'Members appear here once they join Community.'
            : query.isNotEmpty
            ? 'Nothing matches "${_search.text.trim()}".'
            : 'Try another filter.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      itemCount: shown.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final member = shown[i];
        final isMe = member.id == _myId;
        return Semantics(
          button: true,
          label: [
            member.name,
            if (isMe) 'you',
            if (member.verified) 'verified',
            if (member.online) 'online',
            ?member.address,
          ].join(', '),
          excludeSemantics: true,
          child: Material(
            color: HomeTone.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: HomeTone.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _showMember(member),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    _Avatar(member: member, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: _NameLine(member: member)),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HomeTone.violetDim,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      color: HomeTone.violet,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            member.address ??
                                (member.online
                                    ? 'Online now'
                                    : 'Community member'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: member.address == null && member.online
                                  ? HomeTone.green
                                  : HomeTone.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: HomeTone.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member, required this.radius});
  final DirectoryMember member;
  final double radius;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      CircleAvatar(
        radius: radius,
        backgroundColor: HomeTone.violetDim,
        child: Text(
          member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
          style: TextStyle(
            color: HomeTone.violet,
            fontSize: radius * .8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (member.online)
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * .55,
            height: radius * .55,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
    ],
  );
}

class _NameLine extends StatelessWidget {
  const _NameLine({required this.member, this.size = 15.5});
  final DirectoryMember member;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: HomeTone.ink,
            fontSize: size,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (member.verified) ...[
        const SizedBox(width: 4),
        Icon(
          Icons.verified_rounded,
          color: HomeTone.violet,
          size: size + 2,
          semanticLabel: 'Verified',
        ),
      ],
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({
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
            horizontal: icon == null ? 22 : 14,
            vertical: 9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: icon == Icons.circle ? 10 : 18,
                  color: selected
                      ? Colors.white
                      : icon == Icons.circle
                      ? const Color(0xFF22C55E)
                      : HomeTone.violet,
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

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
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
        ],
      ),
    ),
  );
}
