import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../data/mock_transactions.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sort transactions by date, newest first
    mockTransactions.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: const Color(0xFF333333),
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: ListView.builder(
        itemCount: mockTransactions.length,
        itemBuilder: (context, index) {
          final transaction = mockTransactions[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: transaction.isExpense ? const Color(0xFFD32F2F) : Colors.green[400],
                child: Icon(
                  transaction.isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Colors.white,
                ),
              ),
              title: Text(transaction.description, style: const TextStyle(color: Color(0xFF333333))),
              subtitle: Text('${transaction.category} - ${transaction.date.toLocal().toString().split(' ')[0]}', style: TextStyle(color: Colors.grey[600])),
              trailing: Text(
                '${transaction.isExpense ? '-' : '+'}\$${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: transaction.isExpense ? const Color(0xFFD32F2F) : Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
