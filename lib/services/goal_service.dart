import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/goal.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';

class GoalService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TransactionService _transactionService = TransactionService();

  // Get all goals
  Stream<List<Goal>> getGoals() {
    return _db
        .collection('goals')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Goal.fromSnapshot(doc)).toList());
  }

  // Get only active (not completed) goals
  Stream<List<Goal>> getActiveGoals() {
    return _db
        .collection('goals')
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Goal.fromSnapshot(doc)).toList());
  }

  // Add a new goal
  Future<void> addGoal(Goal goal) {
    return _db.collection('goals').add(goal.toJson());
  }

  // Update an existing goal
  Future<void> updateGoal(Goal goal) {
    return _db.collection('goals').doc(goal.id).update(goal.toJson());
  }

  // Delete a goal
  Future<void> deleteGoal(String id) {
    return _db.collection('goals').doc(id).delete();
  }

  // Automated monthly deduction logic
  Future<void> processMonthlySavings() async {
    final query = await _db
        .collection('goals')
        .where('isCompleted', isEqualTo: false)
        .get();
    final now = DateTime.now();
    for (final doc in query.docs) {
      final goal = Goal.fromSnapshot(doc as DocumentSnapshot<Map<String, dynamic>>);
      // Check if deduction is due (not done this month)
      if (goal.lastDeductionDate == null ||
          goal.lastDeductionDate!.year != now.year ||
          goal.lastDeductionDate!.month != now.month) {
        final monthsLeft = (goal.endDate.year - now.year) * 12 + (goal.endDate.month - now.month) + 1;
        if (monthsLeft <= 0) continue;
        final remaining = goal.targetAmount - goal.currentAmount;
        if (remaining <= 0) continue;
        final monthlyAmount = (remaining / monthsLeft).clamp(0, remaining);
        // Create a saving transaction
        final savingTx = Transaction(
          date: now,
          description: 'Automated saving for goal: ${goal.title}',
          amount: monthlyAmount.toDouble(),
          category: 'Saving',
          isExpense: true,
          type: 'saving',
        );
        await _transactionService.addTransaction(savingTx);
        // Update goal
        final updatedGoal = Goal(
          id: goal.id,
          title: goal.title,
          targetAmount: goal.targetAmount,
          currentAmount: goal.currentAmount + monthlyAmount,
          startDate: goal.startDate,
          endDate: goal.endDate,
          description: goal.description,
          isCompleted: (goal.currentAmount + monthlyAmount) >= goal.targetAmount,
          lastDeductionDate: now,
        );
        await updateGoal(updatedGoal);
      }
    }
  }
} 