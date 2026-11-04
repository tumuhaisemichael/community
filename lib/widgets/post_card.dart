import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'post_map_sheet.dart';
import 'post_media.dart';
import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../services/auth_service.dart';
import '../theme/home_tone.dart';
import 'community_ui.dart';
import 'report_row.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.authService,
    required this.postRepository,
    this.currentLocation,
  });

  final CommunityPost post;

  /// Used to show how far away the report is.
  final LatLng? currentLocation;
  final AuthService authService;
  final PostRepository postRepository;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final TextEditingController _commentController = TextEditingController();
  bool _showComments = false;
  bool _isSendingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  CommunityPost get post => widget.post;

  String get _currentUserId => widget.authService.currentUser?.uid ?? '';

  String get _currentUserName {
    final user = widget.authService.currentUser;
    if (user?.displayName?.trim().isNotEmpty == true) {
      return user!.displayName!.trim();
    }
    if (user?.email?.trim().isNotEmpty == true) {
      return user!.email!.trim().split('@').first;
    }
    return 'Member';
  }

  Future<void> _toggleLike() async {
    if (_currentUserId.isEmpty) {
      _showMessage('Sign in to like updates.');
      return;
    }

    try {
      await widget.postRepository.toggleLike(
        postId: post.id,
        userId: _currentUserId,
      );
    } catch (error) {
      _showMessage('Could not update like: $error');
    }
  }

  Future<void> _toggleFlag() async {
    if (_currentUserId.isEmpty) {
      _showMessage('Sign in to flag updates.');
      return;
    }

    try {
      await widget.postRepository.toggleFlag(
        postId: post.id,
        userId: _currentUserId,
      );
    } catch (error) {
      _showMessage('Could not update flag: $error');
    }
  }

  Future<void> _toggleVerification() async {
    try {
      await widget.postRepository.setVerification(
        postId: post.id,
        isVerified: !post.isVerified,
      );
    } catch (error) {
      _showMessage('Could not update verification: $error');
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (_currentUserId.isEmpty) {
      _showMessage('Sign in to comment.');
      return;
    }

    setState(() => _isSendingComment = true);

    try {
      await widget.postRepository.addComment(
        postId: post.id,
        comment: PostComment(
          id: '',
          authorId: _currentUserId,
          authorName: _currentUserName,
          content: text,
          createdAt: DateTime.now(),
        ),
      );
      _commentController.clear();
    } catch (error) {
      _showMessage('Could not add comment: $error');
    } finally {
      if (mounted) {
        setState(() => _isSendingComment = false);
      }
    }
  }

  Future<void> _showLocation() async {
    final latitude = post.latitude;
    final longitude = post.longitude;
    if (latitude == null || longitude == null) return;

    await PostMapSheet.show(
      context,
      post,
      currentLocation: widget.currentLocation,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _share() {
    final text = [
      if (post.categories.any((c) => c != PostCategory.general))
        post.categoriesLabel,
      post.content,
    ].join(': ');
    Clipboard.setData(ClipboardData(text: '$text\n— shared from Community'));
    _showMessage('Copied. Paste it anywhere to share.');
  }

  void _openImages() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: PostImages(post: post, height: 280),
        ),
      ),
    );
  }

  String get _title {
    final picked = post.categories.where((c) => c != PostCategory.general);
    if (picked.isEmpty) return 'Announcement';
    return picked.map((c) => c.label).join(', ');
  }

  String? get _whereLabel {
    final lat = post.latitude;
    final lng = post.longitude;
    if (lat == null || lng == null) return null;
    final here = widget.currentLocation;
    if (here == null) return 'Location pinned';
    final km =
        const Distance().as(LengthUnit.Meter, here, LatLng(lat, lng)) / 1000;
    return 'Pinned location (${distanceLabel(km).replaceFirst('~', '')})';
  }

  @override
  Widget build(BuildContext context) {
    final color = HomeTone.severity(post.severity);
    final isLiked = post.isLikedBy(_currentUserId);
    final isFlaggedByUser = post.isFlaggedBy(_currentUserId);
    final hasLocation = post.latitude != null && post.longitude != null;
    final flagged = post.flags > 0;
    final where = _whereLabel;
    final author = post.isAnonymous ? 'Anonymous' : post.authorName;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: flagged ? const Color(0xFFFFF6F4) : HomeTone.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: flagged ? HomeTone.red : HomeTone.border,
          width: flagged ? 1.4 : 1,
        ),
        boxShadow: HomeTone.cardShadow,
      ),
      child: Stack(
        children: [
          // Severity bar down the left edge, as tall as the card.
          Positioned(
            left: 10,
            top: 12,
            bottom: 12,
            width: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: StreamBuilder<List<PostComment>>(
              stream: widget.postRepository.getCommentsStream(post.id),
              builder: (context, commentsSnapshot) {
                final comments = commentsSnapshot.data ?? const <PostComment>[];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (flagged) _flagBanner(),
                      _header(color, author, isFlaggedByUser),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.content,
                                    style: const TextStyle(
                                      color: HomeTone.ink,
                                      fontSize: 13.5,
                                      height: 1.45,
                                    ),
                                  ),
                                  if (where != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 18,
                                          color: HomeTone.muted,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            where,
                                            style: const TextStyle(
                                              color: HomeTone.muted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Semantics(
                              button: true,
                              label: 'View photos',
                              child: GestureDetector(
                                onTap: _openImages,
                                child: SizedBox(
                                  width: 112,
                                  child: PostImages(
                                    post: post,
                                    height: 80,
                                    firstOnly: true,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: HomeTone.border),
                      Row(
                        children: [
                          _ActionPill(
                            icon: isLiked
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_up_outlined,
                            label: '${post.likes}',
                            semanticLabel: isLiked ? 'Unlike' : 'Like',
                            onTap: _toggleLike,
                            foreground: isLiked
                                ? HomeTone.violet
                                : HomeTone.ink,
                          ),
                          _ActionPill(
                            icon: _showComments
                                ? Icons.chat_bubble_rounded
                                : Icons.chat_bubble_outline_rounded,
                            label: '${comments.length}',
                            semanticLabel: 'Comments',
                            onTap: () =>
                                setState(() => _showComments = !_showComments),
                            foreground: _showComments
                                ? HomeTone.violet
                                : HomeTone.ink,
                          ),
                          _ActionPill(
                            icon: Icons.reply_rounded,
                            mirrorIcon: true,
                            label: 'Share',
                            onTap: _share,
                            foreground: HomeTone.ink,
                          ),
                          // Takes the leftover space and shortens its label
                          // on narrow screens instead of overflowing.
                          if (hasLocation)
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _ActionPill(
                                  icon: Icons.location_on_outlined,
                                  label: 'View on map',
                                  onTap: _showLocation,
                                  foreground: HomeTone.violet,
                                  bold: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_showComments) _comments(commentsSnapshot, comments),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagBanner() => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(0, 0, 8, 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: HomeTone.redDim,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: HomeTone.red),
    ),
    child: Row(
      children: [
        const Icon(Icons.flag_rounded, color: HomeTone.red, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            post.flags == 1
                ? 'Marked as possibly fake by 1 member'
                : 'Marked as possibly fake by ${post.flags} members',
            style: const TextStyle(
              color: HomeTone.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _header(Color color, String author, bool isFlaggedByUser) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(categoryIcon(post.category), color: color, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title,
              style: const TextStyle(
                color: HomeTone.ink,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(
                    '$author  ·  ${timeAgo(post.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: HomeTone.muted, fontSize: 13),
                  ),
                ),
                if (post.isVerified) ...[
                  const SizedBox(width: 4),
                  const Tooltip(
                    message: 'Verified by an admin',
                    child: Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: HomeTone.violet,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          post.severity.label,
          style: TextStyle(
            color: Color.lerp(color, Colors.black, .12),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      SizedBox(
        width: 36,
        height: 30,
        child: PopupMenuButton<String>(
          tooltip: 'More options',
          padding: EdgeInsets.zero,
          color: HomeTone.card,
          icon: const Icon(
            Icons.more_horiz_rounded,
            size: 22,
            color: HomeTone.ink,
          ),
          onSelected: (value) {
            if (value == 'flag') {
              _toggleFlag();
            } else if (value == 'verify') {
              _toggleVerification();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'flag',
              child: Text(
                isFlaggedByUser ? 'Remove fake flag' : 'Flag as fake',
                style: const TextStyle(color: HomeTone.ink),
              ),
            ),
            PopupMenuItem(
              value: 'verify',
              child: Text(
                post.isVerified ? 'Remove admin tag' : 'Verify (admin)',
                style: const TextStyle(color: HomeTone.ink),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _comments(
    AsyncSnapshot<List<PostComment>> snapshot,
    List<PostComment> comments,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 8, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeTone.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeTone.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Replies',
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${comments.length} comment${comments.length == 1 ? '' : 's'}',
                style: const TextStyle(color: HomeTone.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (snapshot.connectionState == ConnectionState.waiting &&
              comments.isEmpty)
            const SkeletonBox(height: 40, color: HomeTone.skeleton)
          else if (comments.isEmpty)
            const Text(
              'No replies yet.',
              style: TextStyle(color: HomeTone.muted),
            )
          else
            for (final comment in comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CommentBubble(comment: comment),
              ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(color: HomeTone.ink),
                  cursorColor: HomeTone.violet,
                  decoration: InputDecoration(
                    hintText: 'Write a reply',
                    hintStyle: const TextStyle(color: HomeTone.muted),
                    filled: true,
                    fillColor: HomeTone.card,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: HomeTone.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: HomeTone.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: HomeTone.violet),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Send reply',
                onPressed: _isSendingComment ? null : _submitComment,
                style: IconButton.styleFrom(
                  backgroundColor: HomeTone.violet,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                ),
                icon: _isSendingComment
                    ? const ButtonSpinner()
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.foreground,
    this.semanticLabel,
    this.mirrorIcon = false,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color foreground;
  final String? semanticLabel;
  final bool mirrorIcon;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 21, color: foreground);
    return Semantics(
      button: true,
      label: semanticLabel == null ? null : '$semanticLabel, $label',
      excludeSemantics: semanticLabel != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              mirrorIcon
                  ? Transform.flip(flipX: true, child: iconWidget)
                  : iconWidget,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13.5,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment});

  final PostComment comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeTone.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeTone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HomeTone.violetDim,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              comment.authorName.isEmpty
                  ? '?'
                  : comment.authorName[0].toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: HomeTone.violet),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: HomeTone.ink),
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, HH:mm').format(comment.createdAt),
                      style: const TextStyle(
                        color: HomeTone.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: HomeTone.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
