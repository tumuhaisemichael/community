import 'package:flutter/material.dart';

import '../models/community_post.dart';

/// Image bundled with the app, shown for posts without uploaded photos.
const String kDefaultPostImage = 'assets/images/report_default.jpg';

/// A post's photos in a horizontal strip, or the default image when the post
/// has none. Photos that fail to load also fall back to the default image.
class PostImages extends StatelessWidget {
  const PostImages({
    super.key,
    required this.post,
    this.height = 176,
    this.firstOnly = false,
  });

  final CommunityPost post;
  final double height;

  /// Show only the first photo, filling the width (for thumbnails).
  final bool firstOnly;

  Widget _fallback({double? width}) => Image.asset(
    kDefaultPostImage,
    height: height,
    width: width ?? double.infinity,
    fit: BoxFit.cover,
    semanticLabel: 'Illustration of a neighbourhood',
  );

  Widget _photo(String url, {double? width}) => Image.network(
    url,
    height: height,
    width: width ?? double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _fallback(width: width),
  );

  @override
  Widget build(BuildContext context) {
    final urls = post.mediaUrls;
    if (urls.isEmpty || firstOnly || urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(firstOnly ? 14 : 18),
        child: urls.isEmpty ? _fallback() : _photo(urls.first),
      );
    }
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _photo(urls[index], width: 220),
        ),
      ),
    );
  }
}
