import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'community_ui.dart';

class HomeOverview extends StatelessWidget {
  const HomeOverview({
    super.key,
    required this.greeting,
    required this.onAround,
    required this.onSos,
    required this.onReport,
    required this.onVacation,
    required this.onMessages,
    required this.onBulletin,
  });
  final String greeting;
  final VoidCallback onAround;
  final VoidCallback onSos;
  final VoidCallback onReport;
  final VoidCallback onVacation;
  final VoidCallback onMessages;
  final VoidCallback onBulletin;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: CommunityHero(greeting: greeting, onAround: onAround),
      ),
      const SizedBox(height: 18),
      Reveal(
        order: 1,
        child: Material(
          color: AppColors.alertDim,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onSos,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const IconBadge(
                    icon: Icons.sos_rounded,
                    color: AppColors.alert,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need help right now?',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send an SOS to nearby neighbors',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.alert,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      const SectionHeading(
        title: 'Your everyday essentials',
        subtitle: 'A few ways to stay connected.',
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: Reveal(
                  order: 1,
                  child: ActionTile(
                    title: 'Report Incident',
                    subtitle: 'Let neighbors know',
                    icon: Icons.add_alert_outlined,
                    color: AppColors.amber,
                    onTap: onReport,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: Reveal(
                  order: 2,
                  child: ActionTile(
                    title: 'Vacation watch',
                    subtitle: 'Care while you’re away',
                    icon: Icons.cottage_outlined,
                    onTap: onVacation,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: Reveal(
                  order: 3,
                  child: ActionTile(
                    title: 'Messages',
                    subtitle: 'Keep in touch',
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: onMessages,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: Reveal(
                  order: 4,
                  child: ActionTile(
                    title: 'Bulletin board',
                    subtitle: 'What’s happening',
                    icon: Icons.view_agenda_outlined,
                    color: AppColors.amber,
                    onTap: onBulletin,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}
