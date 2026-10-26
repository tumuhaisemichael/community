import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';

class PrivacyControlsScreen extends StatefulWidget {
  const PrivacyControlsScreen({super.key});

  @override
  State<PrivacyControlsScreen> createState() => _PrivacyControlsScreenState();
}

class _PrivacyControlsScreenState extends State<PrivacyControlsScreen> {
  bool _showLocation = true;
  bool _showEmail = false;
  bool _allowMessages = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const PageIntro(
            'Choose what other members of the community can see about you.',
          ),
          SettingsGroup(
            children: [
              SwitchListTile(
                title: const Text('Show approximate location'),
                subtitle: const Text('Visible to verified community members'),
                value: _showLocation,
                onChanged: (val) => setState(() => _showLocation = val),
              ),
              SwitchListTile(
                title: const Text('Show email address'),
                subtitle: const Text('Visible on your community profile'),
                value: _showEmail,
                onChanged: (val) => setState(() => _showEmail = val),
              ),
              SwitchListTile(
                title: const Text('Allow direct messages'),
                subtitle: const Text(
                  'Neighbours can start a private chat with you',
                ),
                value: _allowMessages,
                onChanged: (val) => setState(() => _allowMessages = val),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroup(
            children: [
              ListTile(
                leading: Icon(Icons.block, color: AppColors.alert),
                title: const Text('Blocked users'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  // Show list of blocked users
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
