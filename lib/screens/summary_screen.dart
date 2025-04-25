import 'package:flutter/material.dart';
import '../data/mock_transactions.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double totalIncome = 0;
    double totalExpenses = 0;

    for (var transaction in mockTransactions) {
      if (transaction.isExpense) {
        totalExpenses += transaction.amount;
      } else {
        totalIncome += transaction.amount;
      }
    }

    double netCashFlow = totalIncome - totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Summary'),
        backgroundColor: const Color(0xFF333333),
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFFFAFAFA),
              elevation: 2.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Income', style: TextStyle(fontSize: 18, color: Colors.green[700], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8.0),
                    Text('\$${totalIncome.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, color: Color(0xFF333333), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Card(
               color: const Color(0xFFFAFAFA),
              elevation: 2.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Expenses', style: TextStyle(fontSize: 18, color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                     const SizedBox(height: 8.0),
                    Text('\$${totalExpenses.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, color: Color(0xFF333333), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Card(
               color: const Color(0xFFFAFAFA),
              elevation: 2.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Net Cash Flow', style: TextStyle(fontSize: 18, color: Color(0xFF333333), fontWeight: FontWeight.bold)),
                     const SizedBox(height: 8.0),
                    Text('\$${netCashFlow.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, color: netCashFlow >= 0 ? Colors.green[700] : const Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
             const SizedBox(height: 24.0),
             Text(
              '''
  Placeholder for future AI integration:
  This section could potentially use AI to provide insights, forecasts,
  or personalized financial tips based on the transaction data.
''',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
