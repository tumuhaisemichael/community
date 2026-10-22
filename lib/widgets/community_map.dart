import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../theme/app_theme.dart';

/// A consistent frame for the full-page map tools.
class CommunityMap extends StatelessWidget {
  const CommunityMap({
    super.key,
    required this.options,
    required this.children,
  });
  final MapOptions options;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FlutterMap(options: options, children: children),
      ),
    ),
  );
}
