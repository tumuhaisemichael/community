import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';
import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'safety_tips_screen.dart';
import 'privacy_controls_screen.dart';
import 'feedback_support_screen.dart';

/// A shortcut listed under "Safety tools" on the Me tab.
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.authService,
    this.tools = const [],
  });

  final AuthService authService;
  final List<SettingsTool> tools;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  double _alertRadius = 2.0;

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.hero,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.accent,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.onAccent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    (user?.displayName?.trim().isNotEmpty ?? false)
                        ? user!.displayName!
                        : (user?.email?.split('@').first ?? 'Member'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: AppColors.heroMuted),
                  ),
                ],
              ),
            ),
          ),
          if (widget.tools.isNotEmpty) ...[
            const ListSectionTitle(title: 'SAFETY TOOLS'),
            for (final tool in widget.tools)
              ListTile(
                leading: Icon(tool.icon),
                title: Text(tool.title),
                subtitle: Text(tool.subtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: tool.onTap,
              ),
            const Divider(),
          ],
          const ListSectionTitle(title: 'ACCOUNT'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit profile'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditProfileScreen(authService: widget.authService),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy controls'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyControlsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          const ListSectionTitle(title: 'PREFERENCES'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            trailing: Text(_selectedLanguage),
            onTap: () {
              _showLanguageDialog();
            },
          ),
          const Divider(),
          const ListSectionTitle(title: 'ALERTS'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alert radius: ${_alertRadius.toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Slider(
                  value: _alertRadius,
                  min: 0.5,
                  max: 10.0,
                  divisions: 19,
                  label: '${_alertRadius.toStringAsFixed(1)} km',
                  onChanged: (val) => setState(() => _alertRadius = val),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: const Text('Safety tips'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SafetyTipsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Feedback & support'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FeedbackSupportScreen(authService: widget.authService),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout, color: AppColors.alert),
            title: Text('Log out', style: TextStyle(color: AppColors.alert)),
            // AuthGate swaps to the sign-in screen when the user signs out.
            onTap: widget.authService.signOut,
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: RadioGroup<String>(
          groupValue: _selectedLanguage,
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedLanguage = value);
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final language in [
                'English',
                'Luganda',
                'Swahili',
                'Runyankore',
                'Luo',
              ])
                RadioListTile<String>(title: Text(language), value: language),
            ],
          ),
        ),
      ),
    );
  }
}

class ListSectionTitle extends StatelessWidget {
  const ListSectionTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
