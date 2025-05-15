import 'package:cloud_firestore/cloud_firestore.dart';

class Goal {
  final String? id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String? description;
  final bool isCompleted;
  final DateTime? lastDeductionDate;

  Goal({
    this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.startDate,
    required this.endDate,
    this.description,
    this.isCompleted = false,
    this.lastDeductionDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'description': description,
      'isCompleted': isCompleted,
      'lastDeductionDate': lastDeductionDate != null ? Timestamp.fromDate(lastDeductionDate!) : null,
    };
  }

  factory Goal.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        throw Exception('Invalid date type');
      }
    }
    return Goal(
      id: snapshot.id,
      title: data['title'] ?? '',
      targetAmount: (data['targetAmount'] ?? 0.0).toDouble(),
      currentAmount: (data['currentAmount'] ?? 0.0).toDouble(),
      startDate: parseDate(data['startDate'])!,
      endDate: parseDate(data['endDate'])!,
      description: data['description'],
      isCompleted: data['isCompleted'] ?? false,
      lastDeductionDate: parseDate(data['lastDeductionDate']),
    );
  }
} 