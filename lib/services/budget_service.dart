import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget.dart';

class BudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get all budgets for a user
  Stream<List<Budget>> getBudgets(String userId) {
    return _db
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Budget.fromSnapshot(doc)).toList());
  }

  // Add a new budget
  Future<void> addBudget(Budget budget) {
    return _db.collection('budgets').add(budget.toJson());
  }

  // Update an existing budget
  Future<void> updateBudget(Budget budget) {
    return _db
        .collection('budgets')
        .doc(budget.id)
        .update(budget.toJson());
  }

  // Delete a budget
  Future<void> deleteBudget(String id) {
    return _db.collection('budgets').doc(id).delete();
  }

  // Get budgets for a specific month
  Stream<List<Budget>> getBudgetsForMonth(String userId, DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    return _db
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Budget.fromSnapshot(doc)).toList());
  }

  // Get total budget amount for a month
  Future<double> getTotalBudgetForMonth(String userId, DateTime month) async {
    final List<Budget> budgets = await getBudgetsForMonth(userId, month).first;
    return budgets.fold<double>(0.0, (sum, budget) => sum + budget.amount);
  }
} 