import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';

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
      appBar: AppBar(title: const Text('Emergency')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const PageIntro(
            'In danger right now? Call the police first, then alert your '
            'neighbours.',
          ),
          if (onSos != null) ...[
            Material(
              color: AppColors.alert,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onSos,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sos_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send SOS alert',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            Text(
                              'Posts an SOS with your location after you '
                              'confirm',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: .88),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('Call for help', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...contacts.asMap().entries.map((entry) {
            final contact = entry.value;
            final colors = [
              AppColors.watch,
              AppColors.alert,
              AppColors.sevMedium,
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
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: color.withValues(
                      alpha: AppColors.isDark ? .2 : .1,
                    ),
                    child: Icon(icons[entry.key], color: color),
                  ),
                  title: Text(
                    contact['name']!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    contact['number']!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.mutedText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  trailing: IconButton.filled(
                    tooltip: 'Call ${contact['name']}',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.safe,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.call_rounded),
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
