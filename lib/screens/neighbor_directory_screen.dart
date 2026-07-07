import 'package:flutter/material.dart';
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
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(userData['displayName'] ?? 'Member'),
                subtitle: Text(userData['address'] ?? 'Nearby Neighbor'),
                trailing: userData['isVerified'] == true
                    ? const Icon(Icons.verified, color: Colors.blue, size: 20)
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
