import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/home_tone.dart';
import 'hero_header.dart';
import 'overlap_header.dart';

/// A pushed page in the violet design: header with back button, then the
/// content on the light background, overlapping the header's lower edge.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.badge,
    this.bottomBar,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? badge;

  /// Round header buttons, e.g. a ♡.
  final List<Widget> actions;

  /// Pinned under the content, e.g. a Save button.
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTone.canvas,
        body: PinnedHeader(
          overlap: 28,
          header: PageHeroHeader(
            title: title,
            subtitle: subtitle,
            badge: badge,
            actions: actions,
          ),
          body: ListView(
            padding: EdgeInsets.only(
              bottom: bottomBar == null ? bottom + 24 : 16,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: bottomBar == null
            ? null
            : Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  bottom > 0 ? bottom : 16,
                ),
                child: bottomBar,
              ),
      ),
    );
  }
}

/// White rounded card used for content blocks.
class FrameCard extends StatelessWidget {
  const FrameCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;

  // A Material (not a plain coloured box) so tap ripples on rows inside,
  // such as switches and list tiles, show on the card.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: HomeTone.cardShadow,
      ),
      child: Material(
        color: HomeTone.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: HomeTone.border),
        ),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

/// Icon in a lavender rounded square, with a title (and optional subtitle).
class FrameCardTitle extends StatelessWidget {
  const FrameCardTitle({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color = HomeTone.violet,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  color: HomeTone.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(color: HomeTone.muted, fontSize: 12.5),
              ),
          ],
        ),
      ),
    ],
  );
}

/// Full-width violet button with an optional spinner while busy.
class FramePrimaryButton extends StatelessWidget {
  const FramePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: FilledButton.icon(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: HomeTone.violet,
        foregroundColor: Colors.white,
        disabledBackgroundColor: HomeTone.violet.withValues(alpha: .5),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Icon(icon ?? Icons.check_rounded),
      label: Text(label),
    ),
  );
}

/// Light text field matching the violet design.
InputDecoration frameInput({String? label, String? hint, IconData? icon}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: HomeTone.muted),
    floatingLabelStyle: const TextStyle(color: HomeTone.violet),
    hintStyle: const TextStyle(color: HomeTone.muted),
    prefixIcon: icon == null ? null : Icon(icon, color: HomeTone.muted),
    filled: true,
    fillColor: const Color(0xFFF7F4FD),
    border: border(HomeTone.border),
    enabledBorder: border(HomeTone.border),
    focusedBorder: border(HomeTone.violet, 1.6),
  );
}
