import 'package:flutter/material.dart';

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
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Choose what information is visible to others in the community.'),
          ),
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
            subtitle: const Text('Neighbors can start a private chat with you'),
            value: _allowMessages,
            onChanged: (val) => setState(() => _allowMessages = val),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
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
