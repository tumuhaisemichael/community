import 'package:flutter/material.dart';

import '../theme/home_tone.dart';

/// Header for the Home and Map tabs: the shared violet header (no back
/// button) with the bulletin bell and your profile as round buttons.
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
  });

  final String title;
  final String subtitle;

  /// Letter shown in the avatar.
  final String initial;
  final bool hasAlerts;
  final VoidCallback onOpenBulletin;
  final VoidCallback onOpenMe;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => PageHeroHeader(
    title: title,
    subtitle: subtitle,
    showBack: false,
    bottom: bottom,
    actions: [
      HeaderRoundButton(
        icon: Icons.notifications_none_rounded,
        tooltip: hasAlerts
            ? 'Community bulletin, urgent reports nearby'
            : 'Community bulletin',
        showDot: hasAlerts,
        onPressed: onOpenBulletin,
      ),
      HeaderAvatarButton(initial: initial, onPressed: onOpenMe),
    ],
  );
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
    this.actions = const [],
    this.below,
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final Widget? badge;
  final double overlap;

  /// Laid along the lower edge on a canvas-coloured sheet with rounded top
  /// corners (such as tabs). When set, [overlap] is not used.
  final Widget? bottom;

  /// Buttons at the right of the title row, usually [HeaderRoundButton]s.
  /// When given, they take the place of [badge].
  final List<Widget> actions;

  /// An extra row under the subtitle, such as an area or filter pill.
  final Widget? below;

  /// False for main tabs (Messages, Me), which have nowhere to go back to.
  final bool showBack;

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
          if (badge != null && actions.isEmpty)
            Positioned(right: 36, top: top + 18, child: badge!),
          // Centred and at most 640 wide, so tablets look right.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, top + 6, 20, space + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showBack)
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          )
                        else
                          const SizedBox(width: 8, height: 48),
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
                        if (actions.isNotEmpty)
                          for (final action in actions) ...[
                            const SizedBox(width: 8),
                            action,
                          ]
                        else if (badge != null)
                          const SizedBox(width: 72),
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
                    if (below != null) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: below,
                      ),
                    ],
                  ],
                ),
              ),
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

/// Round white button with a violet icon, for [PageHeroHeader.actions].
class HeaderRoundButton extends StatelessWidget {
  const HeaderRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Red dot on the icon, e.g. for unseen urgent updates.
  final bool showDot;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .92),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: showDot,
        smallSize: 9,
        backgroundColor: HomeTone.red,
        child: Icon(icon, color: HomeTone.actionGradient.last),
      ),
    ),
  );
}

/// Round white button with the user's initial, opening their profile.
class HeaderAvatarButton extends StatelessWidget {
  const HeaderAvatarButton({
    super.key,
    required this.initial,
    required this.onPressed,
  });

  final String initial;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open profile',
    excludeSemantics: true,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: HomeTone.actionGradient.last,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// White pill under a header's subtitle (icon, label, optional ▾).
class HeaderPill extends StatelessWidget {
  const HeaderPill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// When given, the pill shows ▾ and can be tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: HomeTone.violet, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomeTone.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: HomeTone.ink,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Header for a main tab (Messages, Me): the same violet header as every
/// other page, without a back button.
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
  Widget build(BuildContext context) => PageHeroHeader(
    title: title,
    subtitle: subtitle,
    actions: actions,
    bottom: bottom,
    showBack: false,
  );
}

/// Kept for older call sites: the same round button as every header.
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
  Widget build(BuildContext context) =>
      HeaderRoundButton(icon: icon, tooltip: tooltip, onPressed: onPressed);
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
