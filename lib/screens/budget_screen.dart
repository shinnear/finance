import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/budget_service.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  _BudgetScreenState createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final BudgetService _budgetService = BudgetService();
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  DateTime _selectedMonth = DateTime.now();
  final _formKey = GlobalKey<FormState>();
  final bool _isRecurring = false;
  String? _selectedRecurrenceType;
  String? _selectedCategory;

  // Temporary user ID (replace with actual user ID from authentication)
  final String _userId = 'current_user';

  // Track which notifications have been sent (persistent storage)
  Set<String> _notifiedBudgets = {};

  @override
  void initState() {
    super.initState();
    _loadNotifiedBudgets();
    _setupNotificationListener();
  }

  Future<void> _loadNotifiedBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    _notifiedBudgets = prefs.getStringList('notified_budgets')?.toSet() ?? {};
  }

  Future<void> _saveNotifiedBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('notified_budgets', _notifiedBudgets.toList());
  }

  void _setupNotificationListener() {
    _transactionService.getTransactions().listen((transactions) {
      _checkBudgetNotifications(transactions);
    });
  }

  Future<void> _checkBudgetNotifications(List<Transaction> transactions) async {
    try {
      debugPrint('Checking budget notifications...');
      final budgets = await _budgetService.getBudgetsForMonth(_userId, _selectedMonth).first;
      
      for (final budget in budgets) {
        final budgetTransactions = transactions
            .where((t) =>
                t.category == budget.category &&
                t.isExpense &&
                t.date.year == _selectedMonth.year &&
                t.date.month == _selectedMonth.month)
            .toList();

        final spent = budgetTransactions.fold(
            0.0, (sum, transaction) => sum + transaction.amount);
        final percentage = (spent / budget.amount * 100);

        debugPrint('Budget ${budget.category}: ${percentage.toStringAsFixed(1)}% used');

        final String notifKey90 = '${budget.id}_${_selectedMonth.year}_${_selectedMonth.month}_90';
        final String notifKey100 = '${budget.id}_${_selectedMonth.year}_${_selectedMonth.month}_100';

        if (percentage >= 90 && percentage < 100 && !_notifiedBudgets.contains(notifKey90)) {
          debugPrint('Triggering 90% notification for ${budget.category}');
          await _showBudgetNotification(
            notifKey90,
            'Budget Alert',
            "You've used ${percentage.toStringAsFixed(1)}% of your ${budget.category} budget!",
          );
          _notifiedBudgets.add(notifKey90);
          await _saveNotifiedBudgets();
        } else if (percentage >= 100 && !_notifiedBudgets.contains(notifKey100)) {
          debugPrint('Triggering 100% notification for ${budget.category}');
          await _showBudgetNotification(
            notifKey100,
            'Budget Exceeded',
            "You've exceeded your ${budget.category} budget!",
          );
          _notifiedBudgets.add(notifKey100);
          await _saveNotifiedBudgets();
        }
      }
    } catch (e) {
      debugPrint('Error checking budget notifications: $e');
    }
  }

  // Helper to show notification
  Future<void> _showBudgetNotification(String id, String title, String body) async {
    try {
      debugPrint('Attempting to show notification: $title - $body');
      
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'budget_channel',
        'Budget Alerts',
        channelDescription: 'Notifications for budget limits',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        enableVibration: true,
        playSound: true,
      );
      
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      
      await flutterLocalNotificationsPlugin.show(
        id.hashCode,
        title,
        body,
        platformChannelSpecifics,
        payload: 'budget_alert',
      );
      
      debugPrint('Notification shown successfully');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Management'),
        backgroundColor: const Color(0xFF333333),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: StreamBuilder<List<Budget>>(
              stream: _budgetService.getBudgetsForMonth(_userId, _selectedMonth),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final budgets = snapshot.data ?? [];

                if (budgets.isEmpty) {
                  return const Center(
                    child: Text(
                      'No budgets set for this month.\nTap + to add a new budget.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF333333)),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: budgets.length,
                  itemBuilder: (context, index) {
                    final budget = budgets[index];
                    return _buildBudgetCard(budget);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        backgroundColor: const Color(0xFF333333),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(Budget budget) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  budget.category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditBudgetDialog(budget),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteBudget(budget),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Budget: \$${budget.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Transaction>>(
              stream: _transactionService.getTransactions(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final transactions = snapshot.data!
                    .where((t) =>
                        t.category == budget.category &&
                        t.isExpense &&
                        t.date.year == _selectedMonth.year &&
                        t.date.month == _selectedMonth.month)
                    .toList();

                final spent = transactions.fold(
                    0.0, (sum, transaction) => sum + transaction.amount);
                final remaining = budget.amount - spent;
                final percentage = (spent / budget.amount * 100);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: (percentage.clamp(0, 100)) / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage > 100
                            ? Colors.red
                            : percentage > 90
                                ? Colors.orange
                                : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Spent: \$${spent.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Remaining: \$${remaining.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: remaining < 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  void _showAddBudgetDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildBudgetDialog(),
    );
  }

  void _showEditBudgetDialog(Budget budget) {
    showDialog(
      context: context,
      builder: (context) => _buildBudgetDialog(budget: budget),
    );
  }

  Widget _buildBudgetDialog({Budget? budget}) {
    final isEditing = budget != null;
    final amountController = TextEditingController(text: budget?.amount.toString() ?? '');
    DateTime startDate = budget?.startDate ?? _selectedMonth;
    DateTime endDate = budget?.endDate ?? DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    String? selectedCategory = budget?.category;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Budget' : 'Add Budget'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<List<String>>(
                    stream: _categoryService.getExpenseCategories(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Error loading categories');
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      final categories = snapshot.data ?? [];
                      if (categories.isEmpty) {
                        return const Text('No categories available');
                      }
                      return DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        validator: (value) =>
                            value == null ? 'Please select a category' : null,
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                      );
                    },
                  ),
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter an amount';
                      }
                      if (double.tryParse(value!) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_formKey.currentState?.validate() ?? false) {
                  final newBudget = Budget(
                    id: budget?.id,
                    category: selectedCategory!,
                    amount: double.parse(amountController.text),
                    startDate: startDate,
                    endDate: endDate,
                    userId: _userId,
                    isRecurring: false,
                    recurrenceType: null,
                  );

                  if (isEditing) {
                    await _budgetService.updateBudget(newBudget);
                  } else {
                    await _budgetService.addBudget(newBudget);
                  }

                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text(
            'Are you sure you want to delete this budget? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _budgetService.deleteBudget(budget.id!);
    }
  }
} 