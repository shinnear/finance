import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Transaction {
  final String? id;
  final DateTime date; // Changed back to DateTime
  final String description;
  final double amount;
  final String category; // e.g., "Food", "Transport", "Salary", "Rent"
  final bool isExpense; // true for expense, false for income

  Transaction({
    this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.category,
    required this.isExpense,
  });

  // Convert a Transaction object to a Map for Firestore
  Map<String, dynamic> toJson() {
    // Convert DateTime to a standardized String format for Firestore
    return {
      'date': DateFormat(
        'MM/dd/yyyy',
      ).format(date), // Store date as String in 'MM/dd/yyyy' format
      'description': description,
      'amount': amount, // Store amount as double
      'category': category,
      'isExpense': isExpense, // Store boolean directly
    };
  }

  // Create a Transaction object from a Firestore DocumentSnapshot
  factory Transaction.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;

    DateTime parsedDate;
    final dynamic dateValue = data['date'];

    if (dateValue == null) {
      // If date is null, assign a default valid DateTime
      print(
        "Warning: Date value is null in document ${snapshot.id}. Using epoch time.",
      );
      parsedDate = DateTime.fromMillisecondsSinceEpoch(0);
    } else if (dateValue is Timestamp) {
      // If date is stored as Timestamp, convert directly to DateTime
      parsedDate = dateValue.toDate();
    } else if (dateValue is String) {
      // If date is stored as a String, attempt to parse it
      try {
        // Try parsing with the expected format first
        parsedDate = DateFormat('MM/dd/yyyy').parse(dateValue);
      } catch (e) {
        // If parsing with the expected format fails, try other common formats or handle error
        print(
          "Warning: Could not parse date string '$dateValue' with MM/dd/yyyy format in document ${snapshot.id}. Trying default parse.",
        );
        try {
          // Try default ISO 8601 format if it might be stored like that
          parsedDate = DateTime.parse(dateValue);
        } catch (e2) {
          print(
            "Error parsing date string '$dateValue' in document ${snapshot.id}: $e2. Using epoch time.",
          );
          // If all parsing fails, assign a default valid DateTime (e.g., epoch or current time)
          parsedDate = DateTime.fromMillisecondsSinceEpoch(
            0,
          ); // Use epoch time as a fallback
        }
      }
    } else {
      print(
        "Warning: Date value is neither Timestamp nor String in document ${snapshot.id}: $dateValue. Using epoch time.",
      );
      // Handle other types by assigning a default valid DateTime
      parsedDate = DateTime.fromMillisecondsSinceEpoch(
        0,
      ); // Use epoch time as a fallback
    }

    // Handle amount: safely convert to double, handling num, String, or null
    final dynamic amountValue = data['amount'];
    double amountDouble;
    if (amountValue == null) {
      print(
        "Warning: Amount value is null in document ${snapshot.id}. Using 0.0.",
      );
      amountDouble = 0.0;
    } else if (amountValue is num) {
      amountDouble = amountValue.toDouble();
    } else if (amountValue is String) {
      amountDouble = double.tryParse(amountValue) ?? 0.0;
    } else {
      print(
        "Warning: Amount value is not num, String, or null in document ${snapshot.id}: $amountValue. Using 0.0.",
      );
      amountDouble = 0.0;
    }

    // Handle isExpense: safely convert to bool, handling bool, String, or null
    final dynamic isExpenseValue = data['isExpense'];
    bool isExpenseBool;
    if (isExpenseValue == null) {
       print(
        "Warning: isExpense value is null in document ${snapshot.id}. Using false.",
      );
      isExpenseBool = false; // Default to false if null
    } else if (isExpenseValue is bool) {
      isExpenseBool = isExpenseValue;
    } else if (isExpenseValue is String) {
      // Attempt to convert string to bool (e.g., "true" to true, "false" to false)
      isExpenseBool = isExpenseValue.toLowerCase() == 'true';
       if (isExpenseValue.toLowerCase() != 'true' && isExpenseValue.toLowerCase() != 'false') {
           print("Warning: Could not parse isExpense string '$isExpenseValue' in document ${snapshot.id}. Using false.");
       }
    } else {
       print(
        "Warning: isExpense value is not bool, String, or null in document ${snapshot.id}: $isExpenseValue. Using false.",
      );
      isExpenseBool = false; // Default to false for unexpected types
    }

    return Transaction(
      id: snapshot.id,
      date: parsedDate, // Assign the parsed DateTime object
      description: data['description'] ?? '',
      amount: amountDouble, // Assign the parsed double amount
      category: data['category'] ?? '',
      isExpense: isExpenseBool, // Assign the parsed boolean value
    );
  }
}
