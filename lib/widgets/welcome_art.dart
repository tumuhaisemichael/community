import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/home_tone.dart';

/// Size the illustrations are drawn at; they scale to fit.
const welcomeArtAspect = 320 / 230;

const _blob = Color(0xFFF4F0FE);
const _violet = Color(0xFF8B5CF6);
const _violetDeep = Color(0xFF6D28D9);
const _leafDark = Color(0xFF3F9B4F);
const _leafLight = Color(0xFF6CC36F);

/// Soft lavender blob behind each illustration.
void _paintBlob(Canvas c) {
  c.drawPath(
    Path()
      ..moveTo(20, 140)
      ..cubicTo(0, 60, 90, 20, 160, 35)
      ..cubicTo(210, 0, 300, 10, 310, 90)
      ..cubicTo(320, 150, 300, 200, 240, 215)
      ..cubicTo(160, 235, 40, 225, 20, 140)
      ..close(),
    Paint()..color = _blob,
  );
}

/// Scales a 320×230 drawing into [size], centred.
void _fit(Canvas c, Size size) {
  final s = math.min(size.width / 320, size.height / 230);
  c
    ..translate((size.width - 320 * s) / 2, (size.height - 230 * s) / 2)
    ..scale(s);
}

/// The little shop from the Start page: striped awning, lit door and
/// window, a shopping bag, a potted plant and bushes.
class ShopIllustration extends StatelessWidget {
  const ShopIllustration({super.key});

  @override
  Widget build(BuildContext context) => const AspectRatio(
    aspectRatio: welcomeArtAspect,
    child: CustomPaint(painter: _ShopPainter()),
  );
}

class _ShopPainter extends CustomPainter {
  const _ShopPainter();

  @override
  void paint(Canvas c, Size size) {
    _fit(c, size);
    final p = Paint();
    _paintBlob(c);

    // Shadow on the ground.
    p.color = const Color(0xFFECE6FB);
    c.drawOval(
      Rect.fromCenter(center: const Offset(165, 210), width: 270, height: 16),
      p,
    );

    void bush(List<(double, double, double)> circles) {
      for (final (i, (x, y, r)) in circles.indexed) {
        p.color = i.isEven ? _leafDark : _leafLight;
        c.drawCircle(Offset(x, y), r, p);
      }
    }

    bush([(52, 172, 30), (34, 192, 21), (76, 190, 20)]);
    bush([(282, 172, 30), (300, 193, 20), (262, 195, 18)]);

    // Wall, with a shaded right edge.
    p.color = const Color(0xFFF7F2FF);
    c.drawRect(const Rect.fromLTRB(85, 84, 245, 200), p);
    p.color = const Color(0xFFEDE4FE);
    c.drawRect(const Rect.fromLTRB(226, 84, 245, 200), p);

    // Base strip.
    p.color = const Color(0xFF7C3AED);
    c.drawRRect(
      RRect.fromLTRBR(80, 196, 250, 208, const Radius.circular(3)),
      p,
    );

    // Awning: top bar, then stripes with scalloped ends.
    p.color = _violet;
    c.drawRRect(RRect.fromLTRBR(76, 36, 254, 54, const Radius.circular(8)), p);
    const stripes = 7;
    const left = 70.0;
    const sw = 190 / stripes;
    for (var i = 0; i < stripes; i++) {
      p.color = i.isEven ? _violet : Colors.white;
      final x = left + i * sw;
      c
        ..drawRect(Rect.fromLTWH(x, 52, sw, 26), p)
        ..drawArc(Rect.fromLTWH(x, 78 - sw / 2, sw, sw), 0, math.pi, true, p);
    }

    // Door.
    p.color = _violetDeep;
    c.drawRRect(
      RRect.fromLTRBR(100, 108, 140, 199, const Radius.circular(4)),
      p,
    );
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFE9A6), Color(0xFFFBC96B)],
    ).createShader(const Rect.fromLTRB(104, 112, 136, 199));
    c.drawRect(const Rect.fromLTRB(104, 112, 136, 199), p);
    p.shader = null;
    p.color = const Color(0xFFB7791F);
    c.drawCircle(const Offset(130, 156), 2.5, p);

    // Window with a middle bar.
    p.color = _violetDeep;
    c.drawRRect(
      RRect.fromLTRBR(152, 108, 232, 160, const Radius.circular(4)),
      p,
    );
    p.color = const Color(0xFFFFEAAE);
    c.drawRect(const Rect.fromLTRB(156, 112, 228, 156), p);
    p
      ..color = const Color(0xFFF1CF7A)
      ..strokeWidth = 2;
    c.drawLine(const Offset(192, 112), const Offset(192, 156), p);

    // Doorstep.
    p.color = const Color(0xFFF7CFA0);
    c.drawRRect(
      RRect.fromLTRBR(94, 198, 148, 205, const Radius.circular(2)),
      p,
    );

    // Potted plant.
    p.color = _leafLight;
    for (final angle in [-.6, -.2, .25, .6]) {
      c
        ..save()
        ..translate(212, 180)
        ..rotate(angle)
        ..drawOval(const Rect.fromLTWH(-5, -30, 10, 30), p)
        ..restore();
    }
    p.color = const Color(0xFFE6DAFE);
    c.drawPath(
      Path()
        ..moveTo(196, 178)
        ..lineTo(228, 178)
        ..lineTo(224, 208)
        ..lineTo(200, 208)
        ..close(),
      p,
    );
    p.color = const Color(0xFFD8C8FD);
    c.drawRect(const Rect.fromLTRB(194, 176, 230, 183), p);

    // Shopping bag with a cart, in front on the left.
    p
      ..color = const Color(0xFFA78BFA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    c.drawArc(const Rect.fromLTWH(64, 126, 32, 40), math.pi, math.pi, false, p);
    p.style = PaintingStyle.fill;
    p.color = _violet;
    c.drawPath(
      Path()
        ..moveTo(52, 146)
        ..lineTo(108, 146)
        ..lineTo(114, 212)
        ..lineTo(46, 212)
        ..close(),
      p,
    );
    p.color = const Color(0xFF7C3AED);
    c.drawPath(
      Path()
        ..moveTo(100, 146)
        ..lineTo(108, 146)
        ..lineTo(114, 212)
        ..lineTo(104, 212)
        ..close(),
      p,
    );
    _paintIcon(c, Icons.shopping_cart_outlined, const Offset(78, 180), 28);

    // Sparkle.
    p
      ..color = _violet
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    c
      ..drawLine(const Offset(250, 30), const Offset(253, 17), p)
      ..drawLine(const Offset(263, 38), const Offset(273, 28), p)
      ..drawLine(const Offset(268, 52), const Offset(282, 48), p);
  }

  void _paintIcon(Canvas c, IconData icon, Offset centre, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A big icon on a white card over the blob, with small coloured icons
/// floating around it. Used for the other Start page slides.
class IconIllustration extends StatelessWidget {
  const IconIllustration({super.key, required this.icon, required this.chips});
  final IconData icon;

  /// Small icons: what, colour, and where (an [Alignment]).
  final List<(IconData, Color, Alignment)> chips;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: welcomeArtAspect,
    child: LayoutBuilder(
      builder: (context, box) {
        final unit = box.maxHeight / 230;
        return Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _BlobPainter())),
            Center(
              child: Container(
                width: 128 * unit,
                height: 128 * unit,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36 * unit),
                  boxShadow: [
                    BoxShadow(
                      color: HomeTone.violet.withValues(alpha: .16),
                      blurRadius: 24 * unit,
                      offset: Offset(0, 10 * unit),
                    ),
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_violet, _violetDeep],
                  ).createShader(r),
                  child: Icon(icon, size: 76 * unit, color: Colors.white),
                ),
              ),
            ),
            for (final (chipIcon, color, at) in chips)
              Align(
                alignment: at,
                child: Container(
                  width: 50 * unit,
                  height: 50 * unit,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3 * unit),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .3),
                        blurRadius: 12 * unit,
                        offset: Offset(0, 5 * unit),
                      ),
                    ],
                  ),
                  child: Icon(chipIcon, size: 24 * unit, color: Colors.white),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter();

  @override
  void paint(Canvas c, Size size) {
    _fit(c, size);
    _paintBlob(c);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
