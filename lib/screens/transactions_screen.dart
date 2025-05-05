import 'package:flutter/material.dart';
import '../models/transaction.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/transaction_service.dart'; // Import the TransactionService
import 'package:intl/intl.dart'; // Import intl package

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final TransactionService _transactionService = TransactionService(); // Create an instance of the service

  // Helper function to get transactions for a given day from a list
  List<Transaction> _getTransactionsForDay(List<Transaction> transactions, DateTime day) {
    return transactions.where((transaction) {
      // Use the DateTime object directly from the Transaction model
      final transactionDate = transaction.date;
      return transactionDate.year == day.year &&
             transactionDate.month == day.month &&
             transactionDate.day == day.day;
    }).toList();
  }

  // Helper function to get transactions for a given month from a list
  List<Transaction> _getTransactionsForMonth(List<Transaction> transactions, DateTime month) {
     return transactions.where((transaction) {
      // Use the DateTime object directly from the Transaction model
      final transactionDate = transaction.date;
      return transactionDate.year == month.year &&
             transactionDate.month == month.month;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: const Color(0xFF333333),
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2022, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay; // Update focused day as well
                });
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
               _focusedDay = focusedDay;
               // When page changes, if no specific day is selected,
               // update the view to show transactions for the new month.
               if (_selectedDay == null) {
                 setState(() {}); // Trigger rebuild to apply month filter
               } else {
                 // If a day was selected, clear it when the month changes
                 setState(() {
                   _selectedDay = null;
                 });
               }
            },
             onHeaderTapped: (focusedDay) {
               // When the header is tapped, clear selected day and filter by month
               setState(() {
                 _selectedDay = null;
                 _focusedDay = focusedDay; // Ensure focusedDay is correct
               });
             },
             calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
            ),
             headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: Color(0xFF333333), fontSize: 16.0, fontWeight: FontWeight.bold)
            ),
             onCalendarCreated: (controller) {
               // Optional: You can use this to control the calendar programmatically
             },
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: _transactionService.getTransactions(), // Use the service to get the stream
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter transactions based on selected day or focused month from the fetched data
                List<Transaction> allTransactions = snapshot.data ?? [];
                List<Transaction> transactionsToShow;
                if (_selectedDay != null) {
                  transactionsToShow = _getTransactionsForDay(allTransactions, _selectedDay!);
                } else {
                  // If no specific day is selected, filter by the month shown in the calendar header
                  transactionsToShow = _getTransactionsForMonth(allTransactions, _focusedDay);
                  // Sort monthly transactions by date in descending order
                  transactionsToShow.sort((a, b) => b.date.compareTo(a.date));
                }

                if (transactionsToShow.isEmpty) {
                  return const Center(child: Text('No transactions for this period.', style: TextStyle(color: Color(0xFF333333))));
                }

                return ListView.builder(
                  itemCount: transactionsToShow.length,
                  itemBuilder: (context, index) {
                    final transaction = transactionsToShow[index];
                    // Use the DateTime object directly for display and formatting
                    final transactionDate = transaction.date;
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
                        subtitle: Text('${transaction.category} - ${DateFormat('MM/dd/yyyy').format(transactionDate.toLocal())}', style: TextStyle(color: Colors.grey[600])),
                        trailing: Text(
                          '${transaction.isExpense ? '-' : '+'}\$${transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: transaction.isExpense ? const Color(0xFFD32F2F) : Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}
