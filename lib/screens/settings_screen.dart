import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';
import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'safety_tips_screen.dart';
import 'privacy_controls_screen.dart';
import 'feedback_support_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.authService});

  final AuthService authService;

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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.lime,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.ink,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    user?.displayName ?? 'Member',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(color: Color(0xFFC7D9CE)),
                  ),
                ],
              ),
            ),
          ),
          const ListSectionTitle(title: 'Account Settings'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
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
            title: const Text('Privacy Controls'),
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
          const ListSectionTitle(title: 'Preferences'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Enable Notifications'),
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
          const ListSectionTitle(title: 'Alert Settings'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alert Radius: ${_alertRadius.toStringAsFixed(1)} km',
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
            title: const Text('Safety Tips'),
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
            title: const Text('Feedback & Support'),
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
            leading: const Icon(Icons.logout, color: AppColors.alert),
            title: const Text(
              'Logout',
              style: TextStyle(color: AppColors.alert),
            ),
            onTap: () {
              widget.authService.signOut();
              Navigator.pop(context);
            },
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
