import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/home_tone.dart';
import '../widgets/page_frame.dart';

class FeedbackSupportScreen extends StatefulWidget {
  const FeedbackSupportScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<FeedbackSupportScreen> createState() => _FeedbackSupportScreenState();
}

class _FeedbackSupportScreenState extends State<FeedbackSupportScreen> {
  static const _topics = ['Idea', 'Problem', 'Question', 'Other'];

  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  String _topic = 'Idea';

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write your message first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = widget.authService.currentUser;
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'topic': _topic,
        'content': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending feedback: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Feedback & Support',
      subtitle: 'Tell us what is working, what is not, or report a problem.',
      bottomBar: FramePrimaryButton(
        label: 'Send Feedback',
        icon: Icons.send_rounded,
        busy: _isSubmitting,
        onPressed: _submitFeedback,
      ),
      children: [
        FrameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FrameCardTitle(
                icon: Icons.feedback_outlined,
                title: 'Your message',
                subtitle: 'We read every message.',
              ),
              const SizedBox(height: 14),
              const Text(
                'What is it about?',
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in _topics)
                    ChoiceChip(
                      label: Text(topic),
                      selected: _topic == topic,
                      showCheckmark: false,
                      selectedColor: HomeTone.violet,
                      backgroundColor: const Color(0xFFF1EDFA),
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                        color: _topic == topic ? Colors.white : HomeTone.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _topic = topic),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _feedbackController,
                minLines: 5,
                maxLines: 8,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: HomeTone.ink, fontSize: 15),
                cursorColor: HomeTone.violet,
                decoration: frameInput(hint: 'What would you like to tell us?'),
              ),
            ],
          ),
        ),
        const FrameCard(
          child: Row(
            children: [
              Icon(Icons.emergency_outlined, color: HomeTone.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'This is not for emergencies. If you are in danger, call '
                  '999 or use SOS on the Home tab.',
                  style: TextStyle(color: HomeTone.ink, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
