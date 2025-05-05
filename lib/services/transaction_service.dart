import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/transaction.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get all transactions
  Stream<List<Transaction>> getTransactions() {
    return _db.collection('transactions').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Transaction.fromSnapshot(doc)).toList());
  }

  // Add a new transaction
  Future<void> addTransaction(Transaction transaction) {
    return _db.collection('transactions').add(transaction.toJson());
  }

  // Update an existing transaction
  Future<void> updateTransaction(Transaction transaction) {
    return _db
        .collection('transactions')
        .doc(transaction.id)
        .update(transaction.toJson());
  }

  // Delete a transaction
  Future<void> deleteTransaction(String id) {
    return _db.collection('transactions').doc(id).delete();
  }
}
