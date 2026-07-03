import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/community_post.dart';
import '../repositories/post_repository.dart';
import '../screens/post_location_screen.dart';
import '../services/auth_service.dart';

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
        return Colors.blue;
      case PostSeverity.medium:
        return Colors.orange;
      case PostSeverity.high:
        return Colors.red;
      case PostSeverity.critical:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat('HH:mm').format(post.createdAt);
    final severityColor = _severityColor();
    final isLiked = post.isLikedBy(_currentUserId);
    final isFlaggedByUser = post.isFlaggedBy(_currentUserId);
    final hasLocation = post.latitude != null && post.longitude != null;
    final cardColor = post.flags > 0
        ? Colors.red.shade50
        : Theme.of(context).cardColor;
    final borderColor = post.flags > 0 ? Colors.red.shade300 : Colors.black12;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          color: Colors.red.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.flags == 1
                                ? 'Marked as possibly fake by 1 member'
                                : 'Marked as possibly fake by ${post.flags} members',
                            style: TextStyle(
                              color: Colors.red.shade900,
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
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text(
                            post.authorName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (post.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.verified,
                                    color: Colors.blue,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (post.category != PostCategory.general)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: severityColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: severityColor),
                              ),
                              child: Text(
                                post.category.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: severityColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(createdAt),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
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
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(post.content),
                if (post.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: post.mediaUrls.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              post.mediaUrls[index],
                              height: 150,
                              width: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 150,
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.broken_image),
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      onPressed: _toggleLike,
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isLiked
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text('${post.likes} likes'),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _showComments = !_showComments);
                      },
                      icon: Icon(
                        _showComments
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                      ),
                      label: Text('Comments (${comments.length})'),
                    ),
                    const Spacer(),
                    if (hasLocation)
                      IconButton(
                        tooltip: 'View sender location',
                        onPressed: _showLocation,
                        icon: const Icon(
                          Icons.location_pin,
                          color: Colors.redAccent,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (_showComments) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
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
                              child: Text('No comments yet.'),
                            ),
                          )
                        else
                          ...comments.map(
                            (comment) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    child: Text(
                                      comment.authorName.isEmpty
                                          ? '?'
                                          : comment.authorName[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                comment.authorName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              DateFormat(
                                                'MMM d, HH:mm',
                                              ).format(comment.createdAt),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(comment.content),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                minLines: 1,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Write a comment...',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _isSendingComment
                                  ? null
                                  : _submitComment,
                              icon: _isSendingComment
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
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
