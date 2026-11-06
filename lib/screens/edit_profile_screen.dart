import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/home_tone.dart';
import '../widgets/page_frame.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.authService.currentUser?.displayName,
  );
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = widget.authService.currentUser;
      await user?.updateDisplayName(name);
      if (user != null) {
        // merge: works even if the user record does not exist yet.
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': name,
        }, SetOptions(merge: true));
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final name = _nameController.text.trim();
    return PageFrame(
      title: 'Edit Profile',
      subtitle: 'The name your neighbours know you by.',
      bottomBar: FramePrimaryButton(
        label: 'Save Changes',
        busy: _isLoading,
        onPressed: _updateProfile,
      ),
      children: [
        FrameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
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
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: HomeTone.ink, fontSize: 15),
                cursorColor: HomeTone.violet,
                decoration: frameInput(
                  label: 'Full name',
                  icon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'It appears on your reports and messages.',
                style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
              ),
              if ((user?.email ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: TextEditingController(text: user!.email),
                  readOnly: true,
                  enabled: false,
                  style: const TextStyle(color: HomeTone.muted, fontSize: 15),
                  decoration: frameInput(
                    label: 'Email (used to sign in)',
                    icon: Icons.mail_outline_rounded,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
