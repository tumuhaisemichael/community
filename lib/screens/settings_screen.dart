import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/live_value.dart';
import '../services/ui_preferences.dart';
import '../theme/home_tone.dart';
import '../widgets/hero_header.dart';
import '../widgets/overlap_header.dart';
import 'edit_profile_screen.dart';
import 'feedback_support_screen.dart';
import 'privacy_controls_screen.dart';
import 'safety_tips_screen.dart';

/// A shortcut listed under "Safety & Community Tools" on the Me tab.
class SettingsTool {
  const SettingsTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// The Me tab: profile, safety tools, account, preferences and alerts.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.authService,
    this.tools = const [],
    this.profile,
  });

  final AuthService authService;
  final List<SettingsTool> tools;

  /// The signed-in user's record; defaults to Firestore. Tests pass their
  /// own.
  final Stream<Map<String, dynamic>?>? profile;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _languages = [
    'English',
    'Luganda',
    'Swahili',
    'Runyankore',
    'Luo',
  ];

  late final LiveValue<Map<String, dynamic>?> _profile = LiveValue(
    widget.profile ??
        (_userId.isEmpty
            ? Stream.value(null)
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(_userId)
                  .snapshots()
                  .map((doc) => doc.data())),
  );

  String get _userId => widget.authService.currentUser?.uid ?? '';

  @override
  void dispose() {
    _profile.close();
    super.dispose();
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  void _openEditProfile() =>
      _open(EditProfileScreen(authService: widget.authService));

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Tools shown as tiles; "About" has its own button further down.
  List<SettingsTool> get _tileTools => [
    for (final tool in widget.tools)
      if (!tool.title.toLowerCase().startsWith('about')) tool,
  ];

  SettingsTool? get _aboutTool {
    for (final tool in widget.tools) {
      if (tool.title.toLowerCase().startsWith('about')) return tool;
    }
    return null;
  }

  // ---------------------------------------------------------------- sheets

  Future<T?> _sheet<T>(Widget Function(BuildContext) builder) =>
      showModalBottomSheet<T>(
        context: context,
        showDragHandle: true,
        backgroundColor: HomeTone.card,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: builder(context),
          ),
        ),
      );

  Widget _sheetTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
    child: Text(
      text,
      style: const TextStyle(
        color: HomeTone.ink,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _choice(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap, {
    String? subtitle,
  }) => ListTile(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    tileColor: selected ? HomeTone.violetDim : null,
    title: Text(
      label,
      style: TextStyle(
        color: selected ? HomeTone.violet : HomeTone.ink,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(subtitle, style: const TextStyle(color: HomeTone.muted)),
    trailing: selected
        ? const Icon(Icons.check_rounded, color: HomeTone.violet)
        : null,
    onTap: () {
      Navigator.pop(context);
      onTap();
    },
  );

  void _showAllTools() => _sheet<void>(
    (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetTitle('Safety & Community Tools'),
        for (final tool in widget.tools)
          ListTile(
            leading: Icon(tool.icon, color: HomeTone.violet),
            title: Text(
              tool.title,
              style: const TextStyle(
                color: HomeTone.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              tool.subtitle,
              style: const TextStyle(color: HomeTone.muted),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: HomeTone.muted,
            ),
            onTap: () {
              Navigator.pop(context);
              tool.onTap();
            },
          ),
      ],
    ),
  );

  void _showAccountSecurity() {
    final email = widget.authService.currentUser?.email?.trim() ?? '';
    _sheet<void>(
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetTitle('Account Security'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'To change your password, we will email you a secure link.',
              style: TextStyle(color: HomeTone.muted),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: email.isEmpty
                ? null
                : () async {
                    Navigator.pop(context);
                    try {
                      await widget.authService.sendPasswordReset(email);
                      _message('Password reset link sent to $email');
                    } catch (error) {
                      _message('Could not send the email: $error');
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: HomeTone.violet,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
            ),
            icon: const Icon(Icons.lock_reset_rounded),
            label: Text(
              email.isEmpty ? 'No email on this account' : 'Email me a link',
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguage() {
    final prefs = UiPreferences.instance;
    _sheet<void>(
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle('Language'),
          for (final language in _languages)
            _choice(
              context,
              language,
              prefs.language == language,
              () => prefs.setLanguage(language),
            ),
        ],
      ),
    );
  }

  void _showAppearance() {
    final prefs = UiPreferences.instance;
    _sheet<void>(
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle('App Appearance'),
          for (final (key, label, sub) in const [
            ('system', 'System', 'Match your phone'),
            ('light', 'Light', 'Always light'),
            ('dark', 'Dark', 'Always dark'),
          ])
            _choice(
              context,
              label,
              prefs.themeMode == key,
              () => prefs.setThemeMode(key),
              subtitle: sub,
            ),
        ],
      ),
    );
  }

  void _showFontSize() {
    final prefs = UiPreferences.instance;
    _sheet<void>(
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle('Font Size'),
          for (final (key, label) in const [
            ('small', 'Small'),
            ('medium', 'Medium'),
            ('large', 'Large'),
          ])
            _choice(
              context,
              label,
              prefs.textSize == key,
              () => prefs.setTextSize(key),
            ),
        ],
      ),
    );
  }

  void _showStartTab() {
    final prefs = UiPreferences.instance;
    _sheet<void>(
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle('Open the app on'),
          for (final (key, label) in const [
            ('home', 'Home'),
            ('map', 'Map'),
            ('messages', 'Messages'),
          ])
            _choice(
              context,
              label,
              prefs.startTab == key,
              () => prefs.setStartTab(key),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmLogOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HomeTone.card,
        title: const Text(
          'Log out?',
          style: TextStyle(color: HomeTone.ink, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You can sign back in any time with your email and password.',
          style: TextStyle(color: HomeTone.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HomeTone.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    // AuthGate swaps to the sign-in screen when the user signs out.
    if (confirmed == true) await widget.authService.signOut();
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: HomeTone.canvas,
        child: ListenableBuilder(
          listenable: UiPreferences.instance,
          builder: (context, _) => PinnedHeader(
            overlap: 28,
            header: const TabHeroHeader(
              title: 'Me',
              subtitle:
                  'Manage your account, safety tools, and app preferences.',
            ),
            body: ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 16,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _profileCard(),
                      const SizedBox(height: 12),
                      if (_tileTools.isNotEmpty) ...[
                        _toolsCard(),
                        const SizedBox(height: 12),
                      ],
                      _accountCard(),
                      const SizedBox(height: 12),
                      _preferencesCard(),
                      const SizedBox(height: 12),
                      _alertsCard(),
                      const SizedBox(height: 12),
                      _linksRow(),
                      const SizedBox(height: 12),
                      _logOut(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileCard() {
    final user = widget.authService.currentUser;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'Member');
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profile.stream,
      initialData: _profile.latest,
      builder: (context, snapshot) {
        final verified = snapshot.data?['isVerified'] == true;
        final editButton = OutlinedButton.icon(
          onPressed: _openEditProfile,
          style: OutlinedButton.styleFrom(
            foregroundColor: HomeTone.violet,
            minimumSize: const Size(0, 42),
            side: const BorderSide(color: HomeTone.violetDim, width: 2),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit Profile'),
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomeTone.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified_rounded,
                    color: HomeTone.violet,
                    size: 22,
                    semanticLabel: 'Verified',
                  ),
                ],
              ],
            ),
            if ((user?.email ?? '').isNotEmpty)
              Text(
                user!.email!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: HomeTone.muted, fontSize: 13.5),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
              decoration: BoxDecoration(
                color: verified ? HomeTone.greenDim : HomeTone.violetDim,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    verified
                        ? Icons.check_rounded
                        : Icons.person_outline_rounded,
                    size: 15,
                    color: verified ? HomeTone.green : HomeTone.violet,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      verified ? 'Verified Neighbour' : 'Neighbour',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: verified ? HomeTone.green : HomeTone.violet,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final avatar = Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: HomeTone.actionGradient,
                ),
              ),
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              right: -3,
              bottom: -3,
              child: Material(
                color: HomeTone.violet,
                shape: const CircleBorder(
                  side: BorderSide(color: Colors.white, width: 2),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openEditProfile,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 15,
                      color: Colors.white,
                      semanticLabel: 'Change photo',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

        return _Card(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 480;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      avatar,
                      const SizedBox(width: 14),
                      Expanded(child: details),
                      if (wide) editButton,
                    ],
                  ),
                  if (!wide) ...[const SizedBox(height: 12), editButton],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _toolsCard() => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardHeader(
          icon: Icons.verified_user_outlined,
          title: 'Safety & Community Tools',
          action: TextButton(
            onPressed: _showAllTools,
            style: TextButton.styleFrom(foregroundColor: HomeTone.violet),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See All',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _tileTools.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final tool = _tileTools[i];
              return Material(
                color: const Color(0xFFF1EDFA),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: tool.onTap,
                  child: SizedBox(
                    width: 96,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tool.icon, color: HomeTone.violet, size: 26),
                          const SizedBox(height: 6),
                          Text(
                            tool.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomeTone.ink,
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _accountCard() => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CardHeader(
          icon: Icons.person_outline_rounded,
          title: 'Account & Privacy',
        ),
        const SizedBox(height: 6),
        _TwoColumns(
          children: [
            _NavRow(
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              onTap: _openEditProfile,
            ),
            _NavRow(
              icon: Icons.verified_user_outlined,
              title: 'Account Security',
              subtitle: 'Change your password',
              onTap: _showAccountSecurity,
            ),
            _NavRow(
              icon: Icons.lock_outline_rounded,
              title: 'Privacy Controls',
              onTap: () => _open(const PrivacyControlsScreen()),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _preferencesCard() {
    final prefs = UiPreferences.instance;
    final themeLabel = switch (prefs.themeMode) {
      'light' => 'Light',
      'dark' => 'Dark',
      _ => 'System',
    };
    final sizeLabel = switch (prefs.textSize) {
      'small' => 'Small',
      'large' => 'Large',
      _ => 'Medium',
    };
    final startLabel = switch (prefs.startTab) {
      'map' => 'Opens on Map',
      'messages' => 'Opens on Messages',
      _ => 'Opens on Home',
    };
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeader(icon: Icons.tune_rounded, title: 'Preferences'),
          const SizedBox(height: 6),
          _TwoColumns(
            children: [
              _ToggleRow(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Alerts, messages, updates',
                value: prefs.notifications,
                onChanged: prefs.setNotifications,
              ),
              _NavRow(
                icon: Icons.palette_outlined,
                title: 'App Appearance',
                subtitle: themeLabel,
                onTap: _showAppearance,
              ),
              _ToggleRow(
                icon: Icons.swap_horiz_rounded,
                title: 'Moving Shortcut Buttons',
                subtitle: 'Home shortcuts swap places every 5 seconds',
                value: prefs.moveShortcuts,
                onChanged: prefs.setMoveShortcuts,
              ),
              _NavRow(
                icon: Icons.text_fields_rounded,
                title: 'Font Size',
                subtitle: sizeLabel,
                onTap: _showFontSize,
              ),
              _NavRow(
                icon: Icons.language_rounded,
                title: 'Language',
                trailingText: prefs.language,
                onTap: _showLanguage,
              ),
              _NavRow(
                icon: Icons.home_outlined,
                title: 'Home Screen',
                subtitle: startLabel,
                onTap: _showStartTab,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alertsCard() {
    final prefs = UiPreferences.instance;
    final radius = prefs.alertRadiusKm;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeader(
            icon: Icons.location_on_outlined,
            title: 'Alerts & Coverage',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 38, top: 2),
            child: Text(
              'Alert radius: ${radius.toStringAsFixed(1)} km  ·  reports and '
              'neighbours within this distance count as near you',
              style: const TextStyle(color: HomeTone.muted, fontSize: 12.5),
            ),
          ),
          Slider(
            value: radius,
            min: .5,
            max: 10,
            divisions: 19,
            activeColor: HomeTone.violet,
            inactiveColor: HomeTone.border,
            label: '${radius.toStringAsFixed(1)} km',
            semanticFormatterCallback: (v) =>
                'Alert radius ${v.toStringAsFixed(1)} kilometres',
            onChanged: (v) => prefs.setAlertRadiusKm(v, save: false),
            onChangeEnd: prefs.setAlertRadiusKm,
          ),
        ],
      ),
    );
  }

  Widget _linksRow() {
    final about = _aboutTool;
    final links = <(IconData, String, VoidCallback)>[
      (
        Icons.lightbulb_outline_rounded,
        'Safety Tips',
        () => _open(const SafetyTipsScreen()),
      ),
      (
        Icons.feedback_outlined,
        'Feedback & Support',
        () => _open(FeedbackSupportScreen(authService: widget.authService)),
      ),
      if (about != null)
        (Icons.info_outline_rounded, 'About & Guidelines', about.onTap),
    ];
    Widget link((IconData, String, VoidCallback) l) => _Card(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: _NavRow(icon: l.$1, title: l.$2, onTap: l.$3),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            children: [
              for (var i = 0; i < links.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: link(links[i])),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < links.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              link(links[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _logOut() => Material(
    color: const Color(0xFFFDEEF0),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _confirmLogOut,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.logout_rounded, color: HomeTone.red),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Log Out',
                style: TextStyle(
                  color: HomeTone.red,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: HomeTone.red),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ widgets

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HomeTone.border),
      boxShadow: HomeTone.cardShadow,
    ),
    child: child,
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title, this.action});
  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: HomeTone.violet, size: 26),
      const SizedBox(width: 12),
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: HomeTone.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      ?action,
    ],
  );
}

/// Two columns side by side on wide screens, one column on phones.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.children});
  final List<Widget> children;

  Widget _column(List<Widget> items) => Column(
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const Divider(height: 1, color: HomeTone.border),
        items[i],
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) return _column(children);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _column([
              for (var i = 0; i < children.length; i += 2) children[i],
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _column([
              for (var i = 1; i < children.length; i += 2) children[i],
            ]),
          ),
        ],
      );
    },
  );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: HomeTone.violet, size: 23),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: HomeTone.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: HomeTone.muted,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: const TextStyle(color: HomeTone.ink, fontSize: 13.5),
            ),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.chevron_right_rounded, color: HomeTone.ink),
        ],
      ),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: HomeTone.violet, size: 23),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: HomeTone.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: HomeTone.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: HomeTone.violet,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: HomeTone.border,
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
