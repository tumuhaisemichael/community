import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/community_post.dart';
import '../services/ui_preferences.dart';
import '../theme/home_tone.dart';
import 'community_ui.dart';

/// Top of the home tab: SOS, a summary of the last 24 hours nearby, and the
/// four most used shortcuts.
class HomeOverview extends StatelessWidget {
  const HomeOverview({
    super.key,
    required this.posts,
    required this.currentLocation,
    required this.onSosTap,
    required this.onSosTriggered,
    required this.onReport,
    required this.onVacation,
    this.onMarketplace,
    required this.onEmergency,
    required this.onPolice,
    required this.onOpenMap,
  });

  final List<CommunityPost> posts;
  final LatLng? currentLocation;
  final VoidCallback onSosTap;
  final VoidCallback onSosTriggered;
  final VoidCallback onReport;
  final VoidCallback onVacation;

  /// Opens the Marketplace; the shortcut is hidden when null.
  final VoidCallback? onMarketplace;
  final VoidCallback onEmergency;
  final VoidCallback onPolice;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Reveal(
        child: SosHoldButton(onTap: onSosTap, onTriggered: onSosTriggered),
      ),
      const SizedBox(height: 14),
      Reveal(
        order: 1,
        child: AreaPulseCard(
          posts: posts,
          currentLocation: currentLocation,
          onOpenMap: onOpenMap,
        ),
      ),
      const SizedBox(height: 14),
      Reveal(
        order: 2,
        child: ListenableBuilder(
          listenable: UiPreferences.instance,
          builder: (context, _) => _ShortcutRow(
            moving: UiPreferences.instance.moveShortcuts,
            tiles: [
              _Shortcut(
                icon: Icons.campaign_rounded,
                label: 'Report',
                color: HomeTone.violet,
                tint: HomeTone.violetDim,
                onTap: onReport,
              ),
              _Shortcut(
                icon: Icons.add_home_rounded,
                label: 'Vacation watch',
                color: HomeTone.violet,
                tint: HomeTone.violetDim,
                onTap: onVacation,
              ),
              if (onMarketplace != null)
                _Shortcut(
                  icon: Icons.storefront_rounded,
                  label: 'Market place',
                  color: HomeTone.orange,
                  tint: const Color(0xFFFFEDE2),
                  onTap: onMarketplace!,
                ),
              _Shortcut(
                icon: Icons.phone_in_talk_rounded,
                label: 'Emergency',
                color: HomeTone.red,
                tint: HomeTone.redDim,
                onTap: onEmergency,
              ),
              _Shortcut(
                icon: Icons.local_police_rounded,
                label: 'Police',
                color: HomeTone.blue,
                tint: HomeTone.blueDim,
                onTap: onPolice,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Four equal shortcut tiles in a row. When [moving] is on, the tiles shift
/// one place to the left every [interval], sliding smoothly into place.
class _ShortcutRow extends StatefulWidget {
  const _ShortcutRow({required this.tiles, required this.moving});

  final List<Widget> tiles;
  final bool moving;

  static const Duration interval = Duration(seconds: 5);
  static const double gap = 10;

  /// Tiles keep the size they have when four fit across the screen; any
  /// more are reached by scrolling the row sideways.
  static const int visibleTiles = 4;

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  Timer? _timer;

  /// Slot of each tile, indexed by tile.
  late List<int> _slots = List.generate(widget.tiles.length, (i) => i);

  bool get _active => widget.moving && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_ShortcutRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_active) {
      _timer ??= Timer.periodic(_ShortcutRow.interval, (_) => _step());
      return;
    }
    _timer?.cancel();
    _timer = null;
    // Back to the original order when moving is switched off.
    _slots = List.generate(widget.tiles.length, (i) => i);
  }

  void _step() {
    final count = widget.tiles.length;
    setState(() => _slots = [for (final s in _slots) (s - 1 + count) % count]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = _ShortcutRow.gap;
    final count = widget.tiles.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        const across = _ShortcutRow.visibleTiles;
        final width = (constraints.maxWidth - gap * (across - 1)) / across;
        final total = count * width + (count - 1) * gap;
        final row = Stack(
          children: [
            // Invisible copy that gives the row its height, so the tiles can
            // grow with large text.
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < count; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      SizedBox(width: width, child: widget.tiles[i]),
                    ],
                  ],
                ),
              ),
            ),
            for (var i = 0; i < count; i++)
              AnimatedPositioned(
                key: ValueKey(i),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeInOutCubic,
                left: _slots[i] * (width + gap),
                top: 0,
                bottom: 0,
                width: width,
                child: widget.tiles[i],
              ),
          ],
        );
        if (count <= across) return row;
        // Scroll sideways to reach the extra tiles; clipBehavior none so
        // the tiles' shadows are not cut off.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: SizedBox(width: total, child: row),
        );
      },
    );
  }
}

/// Recent reports from the last 24 hours, limited to [AreaPulseCard.radiusKm]
/// when the location is known.
List<CommunityPost> recentNearby(List<CommunityPost> posts, LatLng? here) {
  final since = DateTime.now().subtract(const Duration(hours: 24));
  const distance = Distance();
  return posts.where((post) {
    if (post.createdAt.isBefore(since)) return false;
    if (here == null) return true;
    if (post.latitude == null || post.longitude == null) return false;
    final km = distance.as(
      LengthUnit.Kilometer,
      here,
      LatLng(post.latitude!, post.longitude!),
    );
    return km <= AreaPulseCard.radiusKm;
  }).toList();
}

/// "Within 2 km of you · Last 24 hours" summary card.
class AreaPulseCard extends StatelessWidget {
  const AreaPulseCard({
    super.key,
    required this.posts,
    required this.currentLocation,
    required this.onOpenMap,
  });

  /// The user's alert radius (Me → Alerts & Coverage).
  static double get radiusKm => UiPreferences.instance.alertRadiusKm;

  /// "2 km", "1.5 km".
  static String radiusLabel() {
    final r = radiusKm;
    return r == r.roundToDouble()
        ? '${r.toStringAsFixed(0)} km'
        : '${r.toStringAsFixed(1)} km';
  }

  final List<CommunityPost> posts;
  final LatLng? currentLocation;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final recent = recentNearby(posts, currentLocation);
    final counts = <PostCategory, int>{};
    for (final post in recent) {
      counts[post.category] = (counts[post.category] ?? 0) + 1;
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final scope = currentLocation == null
        ? 'Whole community'
        : 'Within ${radiusLabel()} of you';
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: HomeTone.cardShadow,
      ),
      child: Material(
        color: HomeTone.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: HomeTone.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpenMap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: HomeTone.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$scope • Last 24 hours',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: HomeTone.muted,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: HomeTone.muted,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ReportCountHeadline(
                        recent: recent,
                        fontSize: 18,
                        oneLine: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AreaStatusPill(recent: recent),
                  ],
                ),
                const SizedBox(height: 14),
                if (top.isEmpty)
                  Text(
                    currentLocation == null
                        ? 'Turn on location to see what is happening near you.'
                        : 'Tap to see neighbours and reports on the map.',
                    style: textTheme.bodySmall?.copyWith(color: HomeTone.muted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in top.take(3))
                        _CategoryChip(category: entry.key, count: entry.value),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "3 reports, 1 urgent" with the urgent part in red.
class ReportCountHeadline extends StatelessWidget {
  const ReportCountHeadline({
    super.key,
    required this.recent,
    this.fontSize = 28,
    this.oneLine = false,
  });
  final List<CommunityPost> recent;
  final double fontSize;

  /// Keep to a single line, shrinking further if the space is too narrow.
  final bool oneLine;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: HomeTone.ink,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );
    final text = recent.isEmpty
        ? Text('No reports nearby', style: style)
        : _counts(style);
    if (!oneLine) return text;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: text,
    );
  }

  Widget _counts(TextStyle? style) {
    final serious = recent.where((p) => p.severity.isSerious).length;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: '${recent.length} report${recent.length == 1 ? '' : 's'}',
          ),
          if (serious > 0) ...[
            const TextSpan(text: ', '),
            TextSpan(
              text: '$serious urgent',
              style: const TextStyle(color: HomeTone.red),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Stay alert" / "Calm" / "Quiet" pill for a set of recent reports.
class AreaStatusPill extends StatelessWidget {
  const AreaStatusPill({super.key, required this.recent});
  final List<CommunityPost> recent;

  @override
  Widget build(BuildContext context) {
    final serious = recent.any((p) => p.severity.isSerious);
    final (label, icon, color, tint) = serious
        ? ('Stay alert', Icons.warning_rounded, HomeTone.red, HomeTone.redDim)
        : recent.isEmpty
        ? (
            'Quiet',
            Icons.check_circle_rounded,
            HomeTone.green,
            HomeTone.greenDim,
          )
        : ('Calm', Icons.shield_rounded, HomeTone.violet, HomeTone.violetDim);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.count});
  final PostCategory category;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
    decoration: BoxDecoration(
      color: HomeTone.violetDim,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(categoryIcon(category), size: 17, color: HomeTone.violet),
        const SizedBox(width: 6),
        Text(
          count > 1 ? '${category.label} · $count' : category.label,
          style: TextStyle(
            color: HomeTone.violet,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.tint,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      boxShadow: HomeTone.cardShadow,
    ),
    child: Material(
      color: HomeTone.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: HomeTone.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 98),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: HomeTone.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shown when the location could not be found.
class LocationNotice extends StatelessWidget {
  const LocationNotice({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: HomeTone.noticeBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeTone.noticeBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 26,
            color: HomeTone.noticeIcon,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Couldn’t find your location',
                  style: textTheme.titleSmall?.copyWith(
                    color: HomeTone.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(color: HomeTone.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: HomeTone.violet,
              backgroundColor: HomeTone.card,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              side: BorderSide(color: HomeTone.violet, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
