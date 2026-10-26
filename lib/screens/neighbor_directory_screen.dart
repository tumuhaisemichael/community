import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NeighborDirectoryScreen extends StatelessWidget {
  const NeighborDirectoryScreen({super.key});

  static String _nameOf(Map<String, dynamic> data) {
    final name = (data['displayName'] as String?)?.trim();
    if (name != null && name.isNotEmpty && name.toLowerCase() != 'new member') {
      return name;
    }
    final email = (data['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Member';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neighbours')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList(count: 7);
          }
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load neighbours',
              message: 'Check your connection and try again.',
            );
          }

          final users =
              (snapshot.data?.docs ?? [])
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList()
                ..sort(
                  (a, b) => _nameOf(
                    a,
                  ).toLowerCase().compareTo(_nameOf(b).toLowerCase()),
                );

          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No neighbours yet',
              message: 'Members appear here once they join Community.',
            );
          }

          final verified = users.where((u) => u['isVerified'] == true).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              PageIntro(
                '${users.length} members'
                '${verified > 0 ? ', $verified verified' : ''}.',
              ),
              SettingsGroup(
                children: [
                  for (final user in users)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.watchDim,
                        child: Text(
                          _nameOf(user)[0].toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(_nameOf(user)),
                      subtitle: Text(
                        (user['address'] as String?)?.trim().isNotEmpty == true
                            ? user['address'] as String
                            : 'Community member',
                      ),
                      trailing: user['isVerified'] == true
                          ? Tooltip(
                              message: 'Verified neighbour',
                              child: Icon(
                                Icons.verified_rounded,
                                color: AppColors.watch,
                                size: 20,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
