import 'package:flutter/material.dart';

import '../theme/home_tone.dart';

/// Violet page header shared by the Home and Map tabs: brand, notifications,
/// avatar, a title and a subtitle over a small skyline illustration.
///
/// [bottom] is laid along the lower edge on a canvas-coloured sheet with
/// rounded top corners (the Map tab puts its filter chips there).
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initial,
    required this.hasAlerts,
    required this.onOpenBulletin,
    required this.onOpenMe,
    this.bottom,
    this.bottomSpace = 48,
  });

  final String title;
  final String subtitle;

  /// Letter shown in the avatar.
  final String initial;
  final bool hasAlerts;
  final VoidCallback onOpenBulletin;
  final VoidCallback onOpenMe;
  final Widget? bottom;

  /// Space below the subtitle, before [bottom].
  final double bottomSpace;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: HomeTone.headerGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Positioned(
                right: 0,
                bottom: bottom == null ? 18 : 0,
                child: const IgnorePointer(
                  child: CustomPaint(
                    size: Size(220, 110),
                    painter: _HousesPainter(),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, top + 10, 16, bottomSpace),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: .2),
                              ),
                              child: const Icon(
                                Icons.home_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Community',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: hasAlerts
                                  ? 'Community bulletin, urgent reports nearby'
                                  : 'Community bulletin',
                              onPressed: onOpenBulletin,
                              icon: Badge(
                                isLabelVisible: hasAlerts,
                                smallSize: 10,
                                backgroundColor: HomeTone.red,
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Semantics(
                              button: true,
                              label: 'Open profile',
                              excludeSemantics: true,
                              child: InkWell(
                                onTap: onOpenMe,
                                customBorder: const CircleBorder(),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      color: HomeTone.actionGradient.last,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: .88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (bottom != null)
            // Clipped so content scrolling sideways (the Map filter chips)
            // disappears at the rounded edge instead of spilling over.
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: HomeTone.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: bottom,
            ),
        ],
      ),
    );
  }
}

/// Violet header for a pushed page: back button, title, subtitle and the
/// skyline illustration with an optional [badge] (such as an alert shield).
///
/// Leaves [overlap] pixels of space at the bottom for a sheet to cover.
class PageHeroHeader extends StatelessWidget {
  const PageHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    this.overlap = 28,
    this.bottom,
  });

  final String title;
  final String subtitle;
  final Widget? badge;
  final double overlap;

  /// Laid along the lower edge on a canvas-coloured sheet with rounded top
  /// corners (such as tabs). When set, [overlap] is not used.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final textTheme = Theme.of(context).textTheme;
    final space = bottom == null ? overlap : 0.0;
    final header = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: HomeTone.headerGradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: bottom == null ? overlap - 6 : 0,
            child: const IgnorePointer(
              child: CustomPaint(
                size: Size(200, 100),
                painter: _HousesPainter(),
              ),
            ),
          ),
          if (badge != null)
            Positioned(right: 36, top: top + 18, child: badge!),
          Padding(
            padding: EdgeInsets.fromLTRB(8, top + 6, 20, space + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (badge != null) const SizedBox(width: 72),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    subtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: .9),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (bottom == null) return header;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: HomeTone.headerGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: HomeTone.canvas,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: bottom,
          ),
        ],
      ),
    );
  }
}

/// Violet header for a main tab: large title, subtitle, square action
/// buttons on the right, and an optional [bottom] on a rounded white sheet.
class TabHeroHeader extends StatelessWidget {
  const TabHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: HomeTone.headerGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              const Positioned(
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: Size(200, 96),
                    painter: _HousesPainter(),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 14, 16, 26),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .9),
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final action in actions) ...[
                      const SizedBox(width: 10),
                      action,
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (bottom != null)
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: HomeTone.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: bottom,
            ),
        ],
      ),
    );
  }
}

/// Square white button with a violet icon, for [TabHeroHeader.actions].
class HeaderSquareButton extends StatelessWidget {
  const HeaderSquareButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: HomeTone.actionGradient.last, size: 24),
        ),
      ),
    ),
  );
}

/// Decorative skyline of houses and trees for the header.
class _HousesPainter extends CustomPainter {
  const _HousesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shape = Paint()..color = Colors.white.withValues(alpha: .24);
    final window = Paint()..color = Colors.white.withValues(alpha: .5);
    final trunk = Paint()
      ..color = Colors.white.withValues(alpha: .3)
      ..strokeWidth = 2;

    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..quadraticBezierTo(w * .45, h * .5, w, h * .62)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .1),
    );

    void house(double x, double base, double bw, double bh) {
      canvas.drawRect(Rect.fromLTWH(x, base - bh, bw, bh), shape);
      canvas.drawPath(
        Path()
          ..moveTo(x - bw * .12, base - bh)
          ..lineTo(x + bw / 2, base - bh - bw * .5)
          ..lineTo(x + bw * 1.12, base - bh)
          ..close(),
        shape,
      );
      final ws = bw * .2;
      canvas.drawRect(
        Rect.fromLTWH(x + bw * .16, base - bh * .72, ws, ws),
        window,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + bw * .64, base - bh * .72, ws, ws),
        window,
      );
    }

    void tree(double x, double base, double th) {
      canvas.drawLine(Offset(x, base), Offset(x, base - th), trunk);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, base - th),
          width: th * .55,
          height: th * .85,
        ),
        shape,
      );
    }

    tree(w * .1, h * .95, 30);
    house(w * .2, h * .92, 34, 26);
    house(w * .42, h * .84, 46, 36);
    house(w * .67, h * .88, 32, 24);
    tree(w * .9, h * .82, 40);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
