import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../screens/post_location_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.authService,
    required this.postRepository,
  });

  final CommunityPost post;
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostLocationScreen(
          authorName: post.authorName,
          location: LatLng(latitude, longitude),
          details: post.content,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _severityColor() {
    switch (post.severity) {
      case PostSeverity.low:
        return AppColors.watch;
      case PostSeverity.medium:
        return const Color(0xFFD98924);
      case PostSeverity.high:
        return AppColors.alert;
      case PostSeverity.critical:
        return const Color(0xFF7A3E9D);
    }
  }

  String _severityLabel() {
    switch (post.severity) {
      case PostSeverity.low:
        return 'Routine';
      case PostSeverity.medium:
        return 'Watch';
      case PostSeverity.high:
        return 'Urgent';
      case PostSeverity.critical:
        return 'Critical';
    }
  }

  String _categoryLabel() {
    switch (post.category) {
      case PostCategory.suspiciousPerson:
        return 'Suspicious Person';
      case PostCategory.lostChild:
        return 'Lost Child';
      case PostCategory.vacationWatch:
        return 'Vacation Watch';
      default:
        final raw = post.category.name;
        return raw.isEmpty
            ? 'General'
            : '${raw[0].toUpperCase()}${raw.substring(1)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat('MMM d • HH:mm').format(post.createdAt);
    final severityColor = _severityColor();
    final isLiked = post.isLikedBy(_currentUserId);
    final isFlaggedByUser = post.isFlaggedBy(_currentUserId);
    final hasLocation = post.latitude != null && post.longitude != null;
    final cardColor = post.flags > 0 ? const Color(0xFFFFF7F4) : AppColors.card;
    final borderColor = post.flags > 0 ? AppColors.alert : AppColors.border;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: borderColor, width: post.flags > 0 ? 1.4 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<PostComment>>(
          stream: widget.postRepository.getCommentsStream(post.id),
          builder: (context, commentsSnapshot) {
            final comments = commentsSnapshot.data ?? const <PostComment>[];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.flags > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.alertDim,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.alert),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          color: AppColors.alert,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.flags == 1
                                ? 'Marked as possibly fake by 1 member'
                                : 'Marked as possibly fake by ${post.flags} members',
                            style: TextStyle(
                              color: AppColors.alert,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        post.authorName.isEmpty
                            ? '?'
                            : post.authorName[0].toUpperCase(),
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: severityColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            createdAt,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaBadge(
                                icon: Icons.priority_high_rounded,
                                label: _severityLabel(),
                                tint: severityColor,
                              ),
                              if (post.category != PostCategory.general)
                                _MetaBadge(
                                  icon: Icons.sell_outlined,
                                  label: _categoryLabel(),
                                  tint: AppColors.ink,
                                ),
                              if (post.isVerified)
                                const _MetaBadge(
                                  icon: Icons.verified_rounded,
                                  label: 'Admin verified',
                                  tint: AppColors.watch,
                                ),
                              if (hasLocation)
                                const _MetaBadge(
                                  icon: Icons.location_on_outlined,
                                  label: 'Pinned location',
                                  tint: AppColors.safe,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: PopupMenuButton<String>(
                        tooltip: 'More options',
                        icon: const Icon(Icons.more_horiz_rounded, size: 20),
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
                              isFlaggedByUser
                                  ? 'Remove fake flag'
                                  : 'Flag as fake',
                            ),
                          ),
                          PopupMenuItem(
                            value: 'verify',
                            child: Text(
                              post.isVerified
                                  ? 'Remove admin tag'
                                  : 'Verify (Admin)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    post.content,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppColors.ink),
                  ),
                ),
                if (post.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 176,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: post.mediaUrls.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              post.mediaUrls[index],
                              height: 176,
                              width: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 220,
                                    color: AppColors.canvas,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image),
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ActionPill(
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '${post.likes} likes',
                      onTap: _toggleLike,
                      foreground: isLiked ? AppColors.alert : AppColors.ink,
                      background: isLiked
                          ? AppColors.alertDim
                          : AppColors.canvas,
                    ),
                    _ActionPill(
                      icon: _showComments
                          ? Icons.chat_bubble_rounded
                          : Icons.chat_bubble_outline_rounded,
                      label: 'Comments (${comments.length})',
                      onTap: () {
                        setState(() => _showComments = !_showComments);
                      },
                      foreground: AppColors.watch,
                      background: AppColors.watchDim,
                    ),
                    if (hasLocation)
                      _ActionPill(
                        icon: Icons.location_on_outlined,
                        label: 'View location',
                        onTap: _showLocation,
                        foreground: AppColors.safe,
                        background: AppColors.safeDim,
                      ),
                  ],
                ),
                if (_showComments) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Discussion',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Text(
                              '${comments.length} comment${comments.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (commentsSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (comments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No comments yet. Start the conversation.',
                              ),
                            ),
                          )
                        else
                          ...comments.map(
                            (comment) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CommentBubble(comment: comment),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                minLines: 1,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Add your reply...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              onPressed: _isSendingComment
                                  ? null
                                  : _submitComment,
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.ink,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(48, 48),
                              ),
                              icon: _isSendingComment
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
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
    required this.background,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foreground.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: foreground),
            ),
          ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.watchDim,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              comment.authorName.isEmpty
                  ? '?'
                  : comment.authorName[0].toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.watch),
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
                        ).textTheme.labelLarge?.copyWith(color: AppColors.ink),
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, HH:mm').format(comment.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
