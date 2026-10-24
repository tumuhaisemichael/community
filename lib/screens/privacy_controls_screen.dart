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
      appBar: AppBar(title: const Text('Privacy Controls')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const PageIntro(
            title: 'Your space. Your choice.',
            subtitle:
                'Choose what information is visible to others in the community.',
            eyebrow: 'Privacy controls',
            icon: Icons.lock_outline_rounded,
          ),
          SwitchListTile(
            tileColor: AppColors.card,
            title: const Text('Show approximate location'),
            subtitle: const Text('Visible to verified community members'),
            value: _showLocation,
            onChanged: (val) => setState(() => _showLocation = val),
          ),
          SwitchListTile(
            tileColor: AppColors.card,
            title: const Text('Show email address'),
            subtitle: const Text('Visible on your community profile'),
            value: _showEmail,
            onChanged: (val) => setState(() => _showEmail = val),
          ),
          SwitchListTile(
            tileColor: AppColors.card,
            title: const Text('Allow direct messages'),
            subtitle: const Text('Neighbors can start a private chat with you'),
            value: _allowMessages,
            onChanged: (val) => setState(() => _allowMessages = val),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.block, color: AppColors.alert),
            title: const Text('Blocked Users'),
            onTap: () {
              // Show list of blocked users
            },
          ),
        ],
      ),
    );
  }
}
