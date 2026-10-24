import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/neighborhood_banner.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key, this.onSos});

  final VoidCallback? onSos;

  final List<Map<String, String>> contacts = const [
    {'name': 'Police (Emergency)', 'number': '999'},
    {'name': 'Ambulance', 'number': '912'},
    {'name': 'Fire Department', 'number': '998'},
    {'name': 'Local Council (LCI)', 'number': '0800123456'},
    {'name': 'Child Help Line', 'number': '116'},
  ];

  Future<void> _callNumber(String number) async {
    final Uri launchUri = Uri(scheme: 'tel', path: number);
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NeighborhoodBanner(
            title: 'Help is one call away.',
            eyebrow: 'Emergency Contacts',
            subtitle: 'Get help quickly. A safer community, together.',
          ),
          const SizedBox(height: 24),
          if (onSos != null) ...[
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.alertDim,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.sos_rounded,
                    color: AppColors.alert,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'In immediate danger?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to review and confirm your SOS alert.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onSos,
                    icon: const Icon(Icons.emergency_outlined),
                    label: const Text('Send Alert'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.alert,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
          Text('Call for help', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...contacts.asMap().entries.map((entry) {
            final contact = entry.value;
            final colors = [
              AppColors.watch,
              AppColors.alert,
              const Color(0xFFE78A32),
              AppColors.safe,
              AppColors.watch,
            ];
            final icons = [
              Icons.local_police_outlined,
              Icons.medical_services_outlined,
              Icons.local_fire_department_outlined,
              Icons.groups_outlined,
              Icons.child_care,
            ];
            final color = colors[entry.key];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(icons[entry.key], color: color),
                  ),
                  title: Text(
                    contact['name']!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(contact['number']!),
                  trailing: IconButton.filledTonal(
                    tooltip: 'Call ${contact['name']}',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.safeDim,
                      foregroundColor: AppColors.safe,
                    ),
                    icon: const Icon(Icons.call),
                    onPressed: () => _callNumber(contact['number']!),
                  ),
                  onTap: () => _callNumber(contact['number']!),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
