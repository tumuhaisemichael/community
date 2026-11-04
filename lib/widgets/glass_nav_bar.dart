import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/home_tone.dart';

class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating frosted-glass bottom bar with a round action button that sits in
/// a curved notch.
///
/// The action button can be dragged sideways to any slot. While it moves, the
/// tabs slide apart to make room and the notch follows it. On release it
/// snaps to the nearest slot and [onActionMoved] reports the new slot.
class GlassNavBar extends StatefulWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.actionSlot,
    required this.onAction,
    required this.onActionMoved,
    this.actionIcon = Icons.add_rounded,
    this.actionLabel = 'Report',
    this.actionSemanticLabel = 'Report an incident',
  });

  final List<GlassNavItem> items;

  /// Index into [items] of the current tab.
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Slot the action button occupies, from 0 to `items.length`.
  final int actionSlot;
  final VoidCallback onAction;
  final ValueChanged<int> onActionMoved;
  final IconData actionIcon;
  final String actionLabel;
  final String actionSemanticLabel;

  static const double barHeight = 68;
  static const double buttonSize = 60;

  /// Space above the glass that the action button rises into.
  static const double rise = 34;

  static const double _margin = 12;
  static const double _inset = 10;
  static const double _radius = 24;

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar> {
  double? _dragX;
  int? _hoverSlot;
  double _slotW = 0;

  int get _slots => widget.items.length + 1;

  double _centerOf(int slot) => GlassNavBar._inset + _slotW * (slot + .5);

  int _slotAt(double x) =>
      ((x - GlassNavBar._inset) / _slotW - .5).round().clamp(0, _slots - 1);

  void _dragStart(DragStartDetails _) {
    HapticFeedback.lightImpact();
    setState(() {
      _dragX = _centerOf(widget.actionSlot);
      _hoverSlot = widget.actionSlot;
    });
  }

  void _dragUpdate(DragUpdateDetails details) {
    final x = (_dragX! + details.delta.dx).clamp(
      _centerOf(0),
      _centerOf(_slots - 1),
    );
    final slot = _slotAt(x);
    if (slot != _hoverSlot) HapticFeedback.selectionClick();
    setState(() {
      _dragX = x;
      _hoverSlot = slot;
    });
  }

  void _dragEnd([DragEndDetails? _]) {
    final slot = _hoverSlot ?? widget.actionSlot;
    setState(() {
      _dragX = null;
      _hoverSlot = null;
    });
    if (slot != widget.actionSlot) widget.onActionMoved(slot);
  }

  void _moveBy(int step) {
    final slot = (widget.actionSlot + step).clamp(0, _slots - 1);
    if (slot != widget.actionSlot) widget.onActionMoved(slot);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        GlassNavBar._margin,
        0,
        GlassNavBar._margin,
        bottom > 0 ? bottom : 12,
      ),
      child: SizedBox(
        height: GlassNavBar.rise + GlassNavBar.barHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _slotW = (constraints.maxWidth - GlassNavBar._inset * 2) / _slots;
            final dragging = _dragX != null;
            final actionSlot = _hoverSlot ?? widget.actionSlot;

            return TweenAnimationBuilder<double>(
              tween: Tween(end: _dragX ?? _centerOf(actionSlot)),
              duration: dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, cx, _) => Stack(
                children: [
                  Positioned.fill(
                    top: GlassNavBar.rise,
                    child: IgnorePointer(
                      child: CustomPaint(painter: _GlassShadowPainter(cx)),
                    ),
                  ),
                  Positioned.fill(
                    top: GlassNavBar.rise,
                    child: ClipPath(
                      clipper: _NotchedBarClipper(cx),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: CustomPaint(
                          painter: _GlassPainter(cx),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < widget.items.length; i++)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      left:
                          GlassNavBar._inset +
                          _slotW * (i < actionSlot ? i : i + 1),
                      top: GlassNavBar.rise,
                      width: _slotW,
                      height: GlassNavBar.barHeight,
                      child: _NavItem(
                        item: widget.items[i],
                        selected: i == widget.selectedIndex,
                        onTap: () => widget.onSelect(i),
                      ),
                    ),
                  Positioned(
                    left: cx - _slotW / 2,
                    top: 0,
                    width: _slotW,
                    height: GlassNavBar.rise + GlassNavBar.barHeight,
                    child: _ActionButton(
                      icon: widget.actionIcon,
                      label: widget.actionLabel,
                      semanticLabel: widget.actionSemanticLabel,
                      lifted: dragging,
                      canMoveLeft: widget.actionSlot > 0,
                      canMoveRight: widget.actionSlot < _slots - 1,
                      onTap: widget.onAction,
                      onMoveLeft: () => _moveBy(-1),
                      onMoveRight: () => _moveBy(1),
                      onDragStart: _dragStart,
                      onDragUpdate: _dragUpdate,
                      onDragEnd: _dragEnd,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? HomeTone.violet : HomeTone.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                height: 1.25,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 34 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: HomeTone.violet,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.lifted,
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.onTap,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final bool lifted;
  final bool canMoveLeft;
  final bool canMoveRight;
  final VoidCallback onTap;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      hint: 'Drag sideways to move it along the bar',
      customSemanticsActions: {
        if (canMoveLeft)
          const CustomSemanticsAction(label: 'Move left'): onMoveLeft,
        if (canMoveRight)
          const CustomSemanticsAction(label: 'Move right'): onMoveRight,
      },
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('glass-nav-action'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onHorizontalDragStart: onDragStart,
        onHorizontalDragUpdate: onDragUpdate,
        onHorizontalDragEnd: onDragEnd,
        child: Column(
          children: [
            AnimatedScale(
              scale: lifted ? 1.1 : 1,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: GlassNavBar.buttonSize,
                height: GlassNavBar.buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: HomeTone.actionGradient,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .55),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HomeTone.actionGradient.last.withValues(
                        alpha: lifted ? .5 : .38,
                      ),
                      blurRadius: lifted ? 22 : 14,
                      offset: Offset(0, lifted ? 10 : 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 11),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: HomeTone.muted,
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded bar with a smooth bowl cut out around the action button at [cx].
Path _notchedBarPath(Size size, double cx) {
  final bar = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(GlassNavBar._radius),
      ),
    );
  // Button radius plus a gap; the bowl is a little shallower than it is
  // wide because the button centre sits slightly above the bar.
  const halfWidth = GlassNavBar.buttonSize / 2 + 6;
  const depth = GlassNavBar.buttonSize - (GlassNavBar.rise) + 6;
  const shoulder = 10.0;
  final bowl = Path()
    ..moveTo(cx - halfWidth - shoulder, -40)
    ..lineTo(cx - halfWidth - shoulder, 0)
    ..cubicTo(cx - halfWidth, 0, cx - halfWidth, depth, cx, depth)
    ..cubicTo(
      cx + halfWidth,
      depth,
      cx + halfWidth,
      0,
      cx + halfWidth + shoulder,
      0,
    )
    ..lineTo(cx + halfWidth + shoulder, -40)
    ..close();
  return Path.combine(PathOperation.difference, bar, bowl);
}

class _NotchedBarClipper extends CustomClipper<Path> {
  const _NotchedBarClipper(this.cx);
  final double cx;

  @override
  Path getClip(Size size) => _notchedBarPath(size, cx);

  @override
  bool shouldReclip(_NotchedBarClipper oldClipper) => oldClipper.cx != cx;
}

/// Frosted fill, a light sheen and a bright rim.
class _GlassPainter extends CustomPainter {
  const _GlassPainter(this.cx);
  final double cx;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _notchedBarPath(size, cx);
    final rect = Offset.zero & size;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .42),
            const Color(0xFFF3EEFF).withValues(alpha: .28),
          ],
        ).createShader(rect),
    );
    // Sheen across the upper half, like light catching glass.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: .3),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .95),
            const Color(0xFFD9CCF7).withValues(alpha: .7),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter oldDelegate) => oldDelegate.cx != cx;
}

/// Soft shadow drawn only outside the glass, so it never darkens it.
class _GlassShadowPainter extends CustomPainter {
  const _GlassShadowPainter(this.cx);
  final double cx;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _notchedBarPath(size, cx);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(60)),
      path,
    );
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawPath(
      path.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0xFF4C1D95).withValues(alpha: .16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter oldDelegate) => oldDelegate.cx != cx;
}
