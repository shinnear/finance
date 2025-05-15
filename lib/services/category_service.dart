import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get all categories
  Stream<List<String>> getCategories() {
    return _db.collection('transactions')
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => doc.data()['category'] as String)
              .toSet() // Remove duplicates
              .toList();
          categories.sort(); // Sort alphabetically
          return categories;
        });
  }

  // Get expense categories
  Stream<List<String>> getExpenseCategories() {
    return _db.collection('transactions')
        .where('isExpense', whereIn: [true, 'True', 'true'])
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => doc.data()['category'] as String)
              .toSet() // Remove duplicates
              .toList();
          categories.sort(); // Sort alphabetically
          return categories;
        });
  }

  // Get income categories
  Stream<List<String>> getIncomeCategories() {
    return _db.collection('transactions')
        .where('isExpense', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => doc.data()['category'] as String)
              .toSet() // Remove duplicates
              .toList();
          categories.sort(); // Sort alphabetically
          return categories;
        });
  }
} 