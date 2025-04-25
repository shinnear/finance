class Transaction {
  final DateTime date;
  final String description;
  final double amount;
  final String category; // e.g., "Food", "Transport", "Salary", "Rent"
  final bool isExpense; // true for expense, false for income

  Transaction({
    required this.date,
    required this.description,
    required this.amount,
    required this.category,
    required this.isExpense,
  });
}
