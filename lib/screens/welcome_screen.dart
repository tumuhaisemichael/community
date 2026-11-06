import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/home_tone.dart';
import '../widgets/auth_scene.dart';
import '../widgets/welcome_art.dart';

/// One swipeable slide on the Start page: an illustration and three things
/// you can do.
class _Slide {
  const _Slide(this.art, this.features);
  final Widget art;
  final List<(IconData, String)> features;
}

const _slides = [
  _Slide(
    IconIllustration(
      icon: Icons.shield_rounded,
      chips: [
        (Icons.campaign_rounded, HomeTone.red, Alignment(-.62, -.72)),
        (
          Icons.notifications_active_rounded,
          HomeTone.yellow,
          Alignment(.66, -.6),
        ),
        (Icons.location_on_rounded, HomeTone.green, Alignment(.6, .78)),
      ],
    ),
    [
      (Icons.campaign_rounded, 'Report'),
      (Icons.notifications_active_rounded, 'Alerts'),
      (Icons.map_rounded, 'Map'),
    ],
  ),
  _Slide(ShopIllustration(), [
    (Icons.shopping_cart_rounded, 'Buy'),
    (Icons.sell_rounded, 'Sell'),
    (Icons.groups_rounded, 'Connect'),
  ]),
  _Slide(
    IconIllustration(
      icon: Icons.diversity_3_rounded,
      chips: [
        (Icons.favorite_rounded, Color(0xFFDB2777), Alignment(-.64, -.66)),
        (Icons.chat_bubble_rounded, Color(0xFF7C3AED), Alignment(.66, -.62)),
        (Icons.home_rounded, HomeTone.green, Alignment(-.58, .8)),
      ],
    ),
    [
      (Icons.volunteer_activism_rounded, 'Help'),
      (Icons.chat_bubble_rounded, 'Chat'),
      (Icons.house_rounded, 'Watch'),
    ],
  ),
];

/// The first page people see when signed out: the app icon and name,
/// swipeable slides of what the app does, "Get Started" (create an
/// account) and "Sign In".
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: HomeTone.card,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const AppIcon(size: 104),
            const SizedBox(height: 4),
            const Text(
              'Community',
              style: TextStyle(
                color: HomeTone.ink,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final slide in _slides) _SlideView(slide: slide),
                ],
              ),
            ),
            _Dots(
              count: _slides.length,
              index: _page,
              onTap: (i) => _pages.animateToPage(
                i,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _PillButton(
                label: 'Get Started',
                onPressed: widget.onGetStarted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Already have an account?',
                  style: TextStyle(color: HomeTone.muted, fontSize: 14.5),
                ),
                TextButton(
                  onPressed: widget.onSignIn,
                  style: TextButton.styleFrom(
                    foregroundColor: HomeTone.violet,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: ExcludeSemantics(child: slide.art)),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final (icon, label) in slide.features)
              _Feature(icon: icon, label: label),
          ],
        ),
        const SizedBox(height: 18),
      ],
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFF4EFFE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 32, color: HomeTone.violet),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: HomeTone.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.onTap});
  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        Semantics(
          button: true,
          selected: i == index,
          label: 'Page ${i + 1} of $count',
          child: GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == index ? HomeTone.violet : const Color(0xFFDCD6EA),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(colors: HomeTone.actionGradient),
        boxShadow: [
          BoxShadow(
            color: HomeTone.violet.withValues(alpha: .28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
