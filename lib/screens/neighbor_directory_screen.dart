import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/community_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NeighborDirectoryScreen extends StatelessWidget {
  const NeighborDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neighbor Directory')),
      body: StreamBuilder<QuerySnapshot>(
        // In a real app, you'd have a 'users' collection
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data?.docs ?? [];

          if (users.isEmpty) {
            return const Center(child: Text('No neighbors found yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: users.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return PageIntro(
                  title: 'Familiar faces, nearby.',
                  subtitle: '${users.length} neighbors in your community.',
                  eyebrow: 'Neighbor Directory',
                  icon: Icons.people_outline_rounded,
                );
              }
              final userData = users[index - 1].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const IconBadge(icon: Icons.person_outline_rounded),
                  title: Text(userData['displayName'] ?? 'Member'),
                  subtitle: Text(userData['address'] ?? 'Nearby Neighbor'),
                  trailing: userData['isVerified'] == true
                      ? const Icon(
                          Icons.verified,
                          color: AppColors.watch,
                          size: 20,
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
