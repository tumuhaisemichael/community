import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../theme/app_theme.dart';

/// Small entrance motion, disabled when the system requests reduced motion.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + order.clamp(0, 5) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.color, this.size = 46});
  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.watch;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: AppColors.isDark ? .18 : .09),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(icon, color: tint, size: size * .48),
    );
  }
}

/// One or two lines under the app bar that say what a screen is for.
class PageIntro extends StatelessWidget {
  const PageIntro(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 20),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

/// Friendly placeholder for lists with nothing in them (or that failed).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.watchDim,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// Shared touch and keyboard accessible tile with modest hover/press feedback.
class ActionTile extends StatefulWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color,
    this.compact = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool compact;
  @override
  State<ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<ActionTile> {
  bool _pressed = false;
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .975 : 1,
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 130,
    ),
    child: AnimatedContainer(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: _hovered ? .08 : .025),
            blurRadius: _hovered ? 22 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: _hovered
                ? (widget.color ?? AppColors.watch).withValues(alpha: .4)
                : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onHover: (value) => setState(() => _hovered = value),
          child: Padding(
            padding: EdgeInsets.all(widget.compact ? 14 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: widget.icon,
                      color: (widget.color ?? AppColors.watch),
                      size: widget.compact ? 36 : 44,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      color: AppColors.mutedText.withValues(alpha: .6),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class CommunityHero extends StatelessWidget {
  const CommunityHero({
    super.key,
    required this.greeting,
    required this.onAround,
  });
  final String greeting;
  final VoidCallback onAround;
  @override
  Widget build(BuildContext context) => Reveal(
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.hero,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -50,
            child: ExcludeSemantics(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .06),
                    width: 35,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -25,
            bottom: -100,
            child: ExcludeSemantics(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.lime.withValues(alpha: .10),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.heroMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  'A place to belong.\nA community to rely on.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.16,
                    letterSpacing: -.9,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size(0, 46),
                  ),
                  onPressed: onAround,
                  icon: const Icon(Icons.near_me_outlined, size: 18),
                  label: const Text('Explore around you'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Single source of truth for incident severity colours.
Color severityColor(PostSeverity severity) {
  switch (severity) {
    case PostSeverity.low:
      return AppColors.sevLow;
    case PostSeverity.medium:
      return AppColors.sevMedium;
    case PostSeverity.high:
      return AppColors.sevHigh;
    case PostSeverity.critical:
      return AppColors.sevCritical;
  }
}

/// Pulsing grey block used as a loading placeholder.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 12,
  });
  final double width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return box;
    return FadeTransition(
      opacity: Tween<double>(begin: .45, end: 1).animate(_controller),
      child: box,
    );
  }
}

/// Placeholder rows shaped like list items (avatar + two lines of text).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.padding});
  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: padding ?? const EdgeInsets.fromLTRB(20, 12, 20, 24),
    physics: const NeverScrollableScrollPhysics(),
    itemCount: count,
    separatorBuilder: (_, _) => const SizedBox(height: 18),
    itemBuilder: (_, index) => Semantics(
      label: index == 0 ? 'Loading' : null,
      child: Row(
        children: [
          const SkeletonBox(width: 46, height: 46, radius: 23),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120.0 + (index % 3) * 40, height: 13),
                const SizedBox(height: 8),
                const SkeletonBox(height: 11),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Emergency button that sends only after being held for [holdDuration].
///
/// A plain tap calls [onTap] instead (used to show a confirmation dialog), so
/// screen-reader users and anyone who can't long-press still have a path.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    super.key,
    required this.onTriggered,
    required this.onTap,
    this.holdDuration = const Duration(seconds: 2),
  });
  final VoidCallback onTriggered;
  final VoidCallback onTap;
  final Duration holdDuration;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _hold.value = 0;
      widget.onTriggered();
    }
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send SOS alert',
      hint: 'Double tap to confirm',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPressStart: (_) => _hold.forward(from: 0),
        onLongPressEnd: (_) {
          if (!_hold.isCompleted) _hold.reverse();
        },
        onLongPressCancel: () => _hold.reverse(),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) {
            final holding = _hold.value > 0;
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.alert,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.alert.withValues(alpha: .35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _hold.value,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: .18),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .6),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: .6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                holding
                                    ? 'Keep holding…'
                                    : 'Hold 2 seconds to send SOS',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Posts an urgent alert with your location',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: .88,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

IconData categoryIcon(PostCategory category) {
  switch (category) {
    case PostCategory.theft:
      return Icons.lock_open_rounded;
    case PostCategory.assault:
      return Icons.back_hand_outlined;
    case PostCategory.suspiciousPerson:
      return Icons.person_search_outlined;
    case PostCategory.vandalism:
      return Icons.broken_image_outlined;
    case PostCategory.fire:
      return Icons.local_fire_department_outlined;
    case PostCategory.medical:
      return Icons.medical_services_outlined;
    case PostCategory.accident:
      return Icons.car_crash_outlined;
    case PostCategory.harassment:
      return Icons.record_voice_over_outlined;
    case PostCategory.lostChild:
      return Icons.child_care_outlined;
    case PostCategory.vacationWatch:
      return Icons.cottage_outlined;
    case PostCategory.general:
      return Icons.campaign_outlined;
    case PostCategory.other:
      return Icons.report_gmailerrorred_rounded;
  }
}

/// Small spinner sized to sit inside a filled button while it is busy.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 22,
    child: CircularProgressIndicator(
      strokeWidth: 2.5,
      color: AppColors.onPrimary,
    ),
  );
}

/// Rounded group of settings rows, like a section on iOS/Android settings.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: AppColors.border),
    ),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 16, endIndent: 16),
          children[i],
        ],
      ],
    ),
  );
}

/// Small rounded label for a state ("Active", "Urgent", "3 open days").
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.color, this.icon});
  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: AppColors.isDark ? .22 : .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tint),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
