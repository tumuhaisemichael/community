import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  final List<Map<String, String>> contacts = const [
    {'name': 'Police (Emergency)', 'number': '999'},
    {'name': 'Ambulance', 'number': '912'},
    {'name': 'Fire Department', 'number': '998'},
    {'name': 'Local Council (LCI)', 'number': '0800123456'},
    {'name': 'Child Help Line', 'number': '116'},
  ];

  Future<void> _callNumber(String number) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: number,
    );
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return ListTile(
            leading: const Icon(Icons.phone_in_talk, color: Colors.red),
            title: Text(contact['name']!),
            subtitle: Text(contact['number']!),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () => _callNumber(contact['number']!),
            ),
            onTap: () => _callNumber(contact['number']!),
          );
        },
      ),
    );
  }
}
