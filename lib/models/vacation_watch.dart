import 'package:cloud_firestore/cloud_firestore.dart';

class VacationWatch {
  final String id;
  final String userId;
  final String userName;
  final String address;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> watcherIds;
  final String status; // active, completed, cancelled

  VacationWatch({
    required this.id,
    required this.userId,
    required this.userName,
    required this.address,
    required this.startDate,
    required this.endDate,
    this.watcherIds = const [],
    this.status = 'active',
  });

  factory VacationWatch.fromMap(Map<String, dynamic> data, String id) {
    return VacationWatch(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      address: data['address'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      watcherIds: List<String>.from(data['watcherIds'] ?? []),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'address': address,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'watcherIds': watcherIds,
      'status': status,
    };
  }
}
