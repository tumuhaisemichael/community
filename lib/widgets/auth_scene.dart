import 'dart:math' as math;

import 'package:flutter/material.dart';


/// Violet header for Sign In / Create Account: the app icon, name and
/// tagline over a little neighbourhood (houses, trees and a shop).
/// [compact] shrinks it to a slim bar with the logo, e.g. while typing.
class AuthScene extends StatelessWidget {
  const AuthScene({super.key, this.compact = false});
  final bool compact;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOut,
      height: top + (compact ? 92 : 300),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6), Color(0xFFB9A2FB)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: _duration,
                opacity: compact ? 0 : 1,
                child: const CustomPaint(painter: _NeighbourhoodPainter()),
              ),
            ),
          ),
          // Full: icon, name and tagline, centred.
          Positioned(
            left: 0,
            right: 0,
            top: top + 8,
            child: AnimatedOpacity(
              duration: _duration,
              opacity: compact ? 0 : 1,
              child: ExcludeSemantics(
                excluding: compact,
                child: const Column(
                  children: [
                    AppIcon(size: 92),
                    SizedBox(height: 2),
                    Text(
                      'Community',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Connect · Report · Shop · Thrive',
                      style: TextStyle(
                        color: Color(0xEBFFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Compact: a small icon and the name in a row.
          Positioned(
            left: 0,
            right: 0,
            top: top + 6,
            child: AnimatedOpacity(
              duration: _duration,
              opacity: compact ? 1 : 0,
              child: ExcludeSemantics(
                excluding: !compact,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(size: 42),
                    SizedBox(width: 10),
                    Text(
                      'Community',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The official Community logo (`assets/images/logo.png`).
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.size});
  final double size;

  static const asset = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    semanticLabel: 'Community logo',
  );
}

/// Clouds, hills, houses with lit windows, trees and a shop with a striped
/// awning along the bottom of the header.
class _NeighbourhoodPainter extends CustomPainter {
  const _NeighbourhoodPainter();

  static const _wall = Color(0xFFD9CCFD);
  static const _wallShade = Color(0xFFC4B1FB);
  static const _roof = Color(0xFF6D28D9);
  static const _tree = Color(0xFF7C3AED);
  static const _treeLight = Color(0xFF9F7AF5);
  static const _lit = Color(0xFFFFE08A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Everything stands on this line; the white card covers what's below.
    final ground = h - 22;
    final fill = Paint();

    // Clouds.
    void cloud(double x, double y, double s) {
      fill.color = Colors.white.withValues(alpha: .55);
      canvas
        ..drawOval(Rect.fromLTWH(x, y + s * .35, s * 1.6, s * .55), fill)
        ..drawCircle(Offset(x + s * .55, y + s * .38), s * .36, fill)
        ..drawCircle(Offset(x + s * 1.0, y + s * .3), s * .3, fill);
    }

    cloud(w * .12, h * .2, 34);
    cloud(w * .8, h * .3, 30);

    // Hills, far then near.
    fill.color = Colors.white.withValues(alpha: .14);
    canvas.drawPath(
      Path()
        ..moveTo(0, ground - 60)
        ..quadraticBezierTo(w * .25, ground - 110, w * .5, ground - 62)
        ..quadraticBezierTo(w * .78, ground - 120, w, ground - 70)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      fill,
    );
    fill.color = const Color(0xFFA78BFA).withValues(alpha: .55);
    canvas.drawPath(
      Path()
        ..moveTo(0, ground - 24)
        ..quadraticBezierTo(w * .35, ground - 54, w * .62, ground - 26)
        ..quadraticBezierTo(w * .85, ground - 44, w, ground - 30)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      fill,
    );

    void tree(double x, double height, {bool light = false}) {
      final trunk = Paint()
        ..color = _roof
        ..strokeWidth = 2.5;
      canvas.drawLine(Offset(x, ground), Offset(x, ground - height), trunk);
      fill.color = light ? _treeLight : _tree;
      final path = Path()
        ..moveTo(x, ground - height - height * .55)
        ..quadraticBezierTo(
          x + height * .42,
          ground - height * .9,
          x + height * .3,
          ground - height * .35,
        )
        ..lineTo(x - height * .3, ground - height * .35)
        ..quadraticBezierTo(
          x - height * .42,
          ground - height * .9,
          x,
          ground - height - height * .55,
        )
        ..close();
      canvas.drawPath(path, fill);
    }

    void window(double x, double y, double ww, double wh, {bool lit = true}) {
      fill.color = lit ? _lit : Colors.white.withValues(alpha: .85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, ww, wh),
          const Radius.circular(2),
        ),
        fill,
      );
    }

    void house(double x, double bw, double bh, {bool lit = true}) {
      final top = ground - bh;
      fill.color = _wall;
      canvas.drawRect(Rect.fromLTWH(x, top, bw, bh), fill);
      fill.color = _wallShade;
      canvas.drawRect(Rect.fromLTWH(x + bw * .62, top, bw * .38, bh), fill);
      fill.color = _roof;
      canvas.drawPath(
        Path()
          ..moveTo(x - bw * .1, top)
          ..lineTo(x + bw * .5, top - bw * .42)
          ..lineTo(x + bw * 1.1, top)
          ..close(),
        fill,
      );
      window(x + bw * .14, top + bh * .25, bw * .3, bh * .32, lit: lit);
      window(x + bw * .66, top + bh * .25, bw * .2, bh * .32, lit: false);
    }

    void shop(double x, double bw, double bh) {
      final top = ground - bh;
      fill.color = const Color(0xFF8B5CF6);
      canvas.drawRect(Rect.fromLTWH(x, top, bw, bh), fill);
      window(x + bw * .12, top + bh * .4, bw * .76, bh * .45);
      // Striped awning with a scalloped edge.
      const stripes = 6;
      final sw = (bw * 1.1) / stripes;
      final ax = x - bw * .05;
      final ay = top - 4;
      const ah = 16.0;
      for (var i = 0; i < stripes; i++) {
        fill.color = i.isEven ? Colors.white : const Color(0xFFDDD0FD);
        canvas
          ..drawRect(Rect.fromLTWH(ax + i * sw, ay - ah, sw, ah), fill)
          ..drawArc(
            Rect.fromLTWH(ax + i * sw, ay - sw / 2, sw, sw),
            0,
            math.pi,
            true,
            fill,
          );
      }
    }

    // Left side: trees and two houses.
    tree(w * .05, 44);
    tree(w * .13, 32, light: true);
    house(w * .17, 64, 46);
    house(w * .34, 40, 30, lit: false);
    tree(w * .47, 28, light: true);

    // Right side: a small house, the shop and trees.
    house(w * .6, 38, 30, lit: false);
    shop(w * .74, math.min(78, w * .18), 50);
    tree(w * .95, 46);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The four-colour Google "G", drawn so no image asset is needed.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * .2;
    final rect = Rect.fromCircle(
      center: Offset(s / 2, s / 2),
      radius: s / 2 - stroke / 2,
    );
    double rad(double deg) => deg * math.pi / 180;
    void arc(Color c, double start, double sweep) => canvas.drawArc(
      rect,
      rad(start),
      rad(sweep),
      false,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    arc(const Color(0xFF4285F4), 0, 45); // blue
    arc(const Color(0xFF34A853), 45, 90); // green
    arc(const Color(0xFFFBBC05), 135, 80); // yellow
    arc(const Color(0xFFEA4335), 215, 105); // red
    // The blue bar into the middle.
    canvas.drawRect(
      Rect.fromLTWH(s / 2, s / 2 - stroke / 2, s / 2 - stroke * .05, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
