import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The app's signature visual motif: concentric "beacon" rings, evoking a
/// lighthouse / radar sweep — something watching over the neighborhood.
///
/// Used static (small, as the login logo) or animated + pulsing (large,
/// behind the SOS button on the home screen) via [animate].
class BeaconMark extends StatefulWidget {
  const BeaconMark({
    super.key,
    this.size = 72,
    this.color = AppColors.ink,
    this.animate = false,
  });

  final double size;
  final Color color;
  final bool animate;

  @override
  State<BeaconMark> createState() => _BeaconMarkState();
}

class _BeaconMarkState extends State<BeaconMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2, milliseconds: 400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _BeaconPainter(progress: 0, color: widget.color),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BeaconPainter(
              progress: _controller.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _BeaconPainter extends CustomPainter {
  _BeaconPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;

    // Core dot.
    final corePaint = Paint()..color = color;
    canvas.drawCircle(center, maxRadius * 0.16, corePaint);

    // Two static rings for definition.
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = maxRadius * 0.06;
    canvas.drawCircle(center, maxRadius * 0.46, ringPaint);
    canvas.drawCircle(
      center,
      maxRadius * 0.74,
      ringPaint..color = color.withValues(alpha: 0.3),
    );

    // Animated outward pulse.
    if (progress > 0) {
      final pulseRadius = maxRadius * (0.3 + progress * 0.7);
      final pulseOpacity = (1 - progress).clamp(0.0, 1.0) * 0.45;
      final pulsePaint = Paint()
        ..color = color.withValues(alpha: pulseOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = maxRadius * 0.05;
      canvas.drawCircle(center, pulseRadius, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BeaconPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}