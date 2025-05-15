import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  final String? id;
  final String category;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final String userId;
  final bool isRecurring;
  final String? recurrenceType; // 'monthly', 'weekly', 'yearly', null for one-time

  Budget({
    this.id,
    required this.category,
    required this.amount,
    required this.startDate,
    required this.endDate,
    required this.userId,
    this.isRecurring = false,
    this.recurrenceType,
  });

  // Convert Budget object to Map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'amount': amount,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'userId': userId,
      'isRecurring': isRecurring,
      'recurrenceType': recurrenceType,
    };
  }

  // Create Budget object from Firestore DocumentSnapshot
  factory Budget.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        throw Exception('Invalid date type');
      }
    }
    return Budget(
      id: snapshot.id,
      category: data['category'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      userId: data['userId'] ?? '',
      isRecurring: data['isRecurring'] ?? false,
      recurrenceType: data['recurrenceType'],
    );
  }

  // Create a copy of Budget with some fields updated
  Budget copyWith({
    String? category,
    double? amount,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    bool? isRecurring,
    String? recurrenceType,
  }) {
    return Budget(
      id: id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      userId: userId ?? this.userId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
    );
  }
} 