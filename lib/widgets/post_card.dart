import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_post.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat('HH:mm').format(post.createdAt);

    Color severityColor;
    switch (post.severity) {
      case PostSeverity.low:
        severityColor = Colors.blue;
        break;
      case PostSeverity.medium:
        severityColor = Colors.orange;
        break;
      case PostSeverity.high:
        severityColor = Colors.red;
        break;
      case PostSeverity.critical:
        severityColor = Colors.purple;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      post.authorName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (post.category != PostCategory.general) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
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
                  ],
                ),
                Row(
                  children: [
                    if (post.isVerified)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.verified, color: Colors.blue, size: 16),
                      ),
                    Text(createdAt),
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
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          post.mediaUrls[index],
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 150,
                            color: Colors.grey[300],
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
                Icon(
                  Icons.favorite_border,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text('${post.likes} likes'),
                const Spacer(),
                if (post.latitude != null && post.longitude != null)
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, size: 18),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'flag',
                      child: Text('Flag as fake'),
                    ),
                    const PopupMenuItem(
                      value: 'verify',
                      child: Text('Verify (Admin)'),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'flag') {
                      await FirebaseFirestore.instance
                          .collection('posts')
                          .doc(post.id)
                          .update({'flags': FieldValue.increment(1)});
                    } else if (value == 'verify') {
                      await FirebaseFirestore.instance
                          .collection('posts')
                          .doc(post.id)
                          .update({'isVerified': true});
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
