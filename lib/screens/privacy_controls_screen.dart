import 'package:flutter/material.dart';

import '../theme/home_tone.dart';
import '../widgets/page_frame.dart';

class PrivacyControlsScreen extends StatefulWidget {
  const PrivacyControlsScreen({super.key});

  @override
  State<PrivacyControlsScreen> createState() => _PrivacyControlsScreenState();
}

class _PrivacyControlsScreenState extends State<PrivacyControlsScreen> {
  bool _showLocation = true;
  bool _showEmail = false;
  bool _allowMessages = true;

  Widget _switch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    secondary: Icon(icon, color: HomeTone.violet),
    title: Text(
      title,
      style: const TextStyle(
        color: HomeTone.ink,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: HomeTone.muted, fontSize: 12.5),
    ),
    value: value,
    onChanged: onChanged,
    activeThumbColor: Colors.white,
    activeTrackColor: HomeTone.violet,
    inactiveThumbColor: Colors.white,
    inactiveTrackColor: HomeTone.border,
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  );

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Privacy Controls',
      subtitle: 'Choose what other members can see about you.',
      children: [
        FrameCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 6),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, right: 8, bottom: 6),
                child: FrameCardTitle(
                  icon: Icons.visibility_outlined,
                  title: 'What neighbours see',
                ),
              ),
              _switch(
                icon: Icons.location_on_outlined,
                title: 'Show approximate location',
                subtitle: 'Visible to verified community members',
                value: _showLocation,
                onChanged: (v) => setState(() => _showLocation = v),
              ),
              const Divider(height: 1, color: HomeTone.border),
              _switch(
                icon: Icons.mail_outline_rounded,
                title: 'Show email address',
                subtitle: 'Visible on your community profile',
                value: _showEmail,
                onChanged: (v) => setState(() => _showEmail = v),
              ),
              const Divider(height: 1, color: HomeTone.border),
              _switch(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Allow direct messages',
                subtitle: 'Neighbours can start a private chat with you',
                value: _allowMessages,
                onChanged: (v) => setState(() => _allowMessages = v),
              ),
            ],
          ),
        ),
        FrameCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: const Icon(Icons.block_rounded, color: HomeTone.red),
            title: const Text(
              'Blocked users',
              style: TextStyle(
                color: HomeTone.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'You have not blocked anyone',
              style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: HomeTone.muted,
            ),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You have not blocked anyone.')),
            ),
          ),
        ),
      ],
    );
  }
}
