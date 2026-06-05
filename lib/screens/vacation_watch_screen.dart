import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vacation_watch.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VacationWatchScreen extends StatefulWidget {
  const VacationWatchScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<VacationWatchScreen> createState() => _VacationWatchScreenState();
}

class _VacationWatchScreenState extends State<VacationWatchScreen> {
  final _addressController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final user = widget.authService.currentUser;
    final watch = VacationWatch(
      id: '',
      userId: user?.uid ?? '',
      userName: user?.displayName ?? user?.email ?? 'Member',
      address: _addressController.text.trim(),
      startDate: _startDate!,
      endDate: _endDate!,
    );

    await FirebaseFirestore.instance.collection('vacation_watches').add(watch.toMap());

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vacation watch set up successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vacation Watch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Notify neighbors when you are away so they can keep an eye on your property.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address to Monitor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(_startDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(_startDate!)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _startDate = date);
              },
            ),
            ListTile(
              title: const Text('Expected Return Date'),
              subtitle: Text(_endDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(_endDate!)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: _startDate ?? DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _endDate = date);
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submit,
              child: const Text('Set Up Vacation Watch'),
            ),
          ],
        ),
      ),
    );
  }
}
