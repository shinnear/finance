import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:webview_flutter/webview_flutter.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart'; // Import the TransactionService
import '../services/ml_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
// Import cloud_firestore and hide Transaction
// Import for file operations
// Import for JSON decoding

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  SummaryScreenState createState() => SummaryScreenState();
}

class SummaryScreenState extends State<SummaryScreen> {
  DateTime _selectedMonth = DateTime.now();
  late final WebViewController _mlController;
  bool _isLoadingML = true;

  final TransactionService _transactionService =
      TransactionService(); // Create an instance of the service
  final MLService _mlService = MLService();

  // State variables for ML features
  List<dynamic> _personalizedTips = [];
  Map<String, dynamic> _spendingAnalysis = {};
  Map<String, dynamic> _savingsSuggestions = {};
  Map<String, dynamic> _expenseForecast = {};

  @override
  void initState() {
    super.initState();
    _loadMLFeatures();
  }

  void _initializeMLWebView() {
    _mlController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoadingML = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('http://localhost:8501')); // Streamlit default port
  }

  Future<void> _loadMLFeatures() async {
    setState(() {
      _isLoadingML = true;
    });

    try {
      // Load ML data from assets
      final spendingAnalysisJson = await rootBundle.loadString('assets/ML/spending_analysis_results.json');
      final savingsSuggestionsJson = await rootBundle.loadString('assets/ML/savings_suggestions_results.json');
      final personalizedTipsJson = await rootBundle.loadString('assets/ML/personalized_tips_results.json');
      final expenseForecastJson = await rootBundle.loadString('assets/ML/expense_forecast_results.json');

      setState(() {
        _spendingAnalysis = json.decode(spendingAnalysisJson);
        _savingsSuggestions = json.decode(savingsSuggestionsJson);
        _personalizedTips = json.decode(personalizedTipsJson)['personalized_tips'] ?? [];
        _expenseForecast = json.decode(expenseForecastJson);
      });
    } catch (e) {
      print('Error loading ML features: $e');
    } finally {
      setState(() {
        _isLoadingML = false;
      });
    }
  }

  List<Transaction> _getTransactionsForMonth(
    List<Transaction> transactions,
    DateTime month,
  ) {
    return transactions.where((transaction) {
      // Use the DateTime object directly for comparison
      return transaction.date.year == month.year &&
          transaction.date.month == month.month;
    }).toList();
  }

  double _getTotalIncome(List<Transaction> transactions) {
    return transactions
        .where((transaction) => !transaction.isExpense)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double _getTotalExpenses(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.isExpense)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Map<String, double> _getExpensesByCategory(List<Transaction> transactions) {
    final expenses =
        transactions.where((transaction) => transaction.isExpense).toList();
    final Map<String, double> categoryMap = {};

    for (var transaction in expenses) {
      if (transaction.category != 'Other') { // Exclude 'Other' category
        categoryMap.update(
          transaction.category,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }
    return categoryMap;
  }

  Map<String, Map<String, double>> _getIncomeVsExpensesForLast3Months(
    List<Transaction> transactions,
    DateTime selectedMonth,
  ) {
    final Map<String, Map<String, double>> monthlyData = {};

    for (int i = 0; i < 3; i++) {
      final month = DateTime(selectedMonth.year, selectedMonth.month - i, 1);
      // Ensure we don't go before the first transaction month in the fetched data
      if (transactions.isNotEmpty) {
        // Use the DateTime object directly for comparison
        final firstTransactionDate = transactions.first.date;
        if (month.isBefore(
          DateTime(firstTransactionDate.year, firstTransactionDate.month, 1),
        )) {
          break;
        }
      }
      final monthlyTransactions = _getTransactionsForMonth(transactions, month);
      final totalIncome = _getTotalIncome(monthlyTransactions);
      final totalExpenses = _getTotalExpenses(monthlyTransactions);
      final monthYear = DateFormat('MMM yyyy').format(month);
      monthlyData[monthYear] = {
        'income': totalIncome,
        'expenses': totalExpenses,
      };
    }

    // Sort the months chronologically
    final sortedMonths = monthlyData.keys.toList();
    sortedMonths.sort((a, b) {
      final dateA = DateFormat('MMM yyyy').parse(a);
      final dateB = DateFormat('MMM yyyy').parse(b);
      return dateA.compareTo(dateB);
    });

    final sortedMonthlyData = <String, Map<String, double>>{};
    for (var month in sortedMonths) {
      sortedMonthlyData[month] = monthlyData[month]!;
    }

    return sortedMonthlyData;
  }

  bool isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 20.0, height: 20.0, color: color),
        const SizedBox(width: 8.0),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildMLInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'AI Insights',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (_isLoadingML)
          const Center(child: CircularProgressIndicator())
        else
          SingleChildScrollView(
            child: Column(
              children: [
                _buildSpendingAnalysisSection(),
                _buildSavingsSuggestionsSection(),
                _buildPersonalizedTipsSection(),
                _buildExpenseForecastSection(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSpendingAnalysisSection() {
    if (_spendingAnalysis.isEmpty) return const SizedBox.shrink();

    final spendingPatterns = _spendingAnalysis['spending_patterns'];
    if (spendingPatterns == null) return const SizedBox.shrink();

    final categories = spendingPatterns['spending_by_category'] as List?;
    if (categories == null || categories.isEmpty) return const SizedBox.shrink();

    // Sort categories by sum in descending order
    categories.sort((a, b) => (b['sum'] as double).compareTo(a['sum'] as double));

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Spending Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Total Spending: \$${spendingPatterns['total_spending'].toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Top Spending Categories:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...categories.take(5).map((category) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${category['category']}: \$${category['sum'].toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  Text(
                    '(${category['count']} transactions)',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsSuggestionsSection() {
    if (_savingsSuggestions.isEmpty) return const SizedBox.shrink();

    final suggestions = _savingsSuggestions['savings_suggestions'] as List?;
    if (suggestions == null || suggestions.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.savings, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Savings Suggestions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...suggestions.map((suggestion) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      suggestion['type'] == 'spending_increase' 
                          ? Icons.trending_up 
                          : Icons.lightbulb_outline,
                      color: suggestion['type'] == 'spending_increase' 
                          ? Colors.orange 
                          : Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion['message'],
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                if (suggestion['details'] != null) ...[
                  const SizedBox(height: 8),
                  ...(suggestion['details'] as List).map((detail) => Padding(
                    padding: const EdgeInsets.only(left: 28.0, top: 4.0),
                    child: Text(
                      '• ${detail['category']}: \$${detail['amount'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 12),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizedTipsSection() {
    if (_personalizedTips.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Personalized Tips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._personalizedTips.map((tip) =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      tip['severity'] == 'warning' ? Icons.warning : Icons.info,
                      color: tip['severity'] == 'warning' ? Colors.orange : Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip['message'],
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseForecastSection() {
    if (_expenseForecast.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Expense Forecast',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_expenseForecast['forecast'] != null)
              ...(_expenseForecast['forecast'] as List).map((forecast) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${forecast['month']}: \$${forecast['predicted_amount'].toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Summary'),
        backgroundColor: const Color(0xFF333333),
        actions: [
          StreamBuilder<List<Transaction>>(
            stream:
                _transactionService
                    .getTransactions(), // Use the service to get the stream
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink(); // Hide dropdown if no data
              }
              final allTransactions = snapshot.data!;
              // Populate allMonths from fetched transactions and sort descending
              final allMonths =
                  allTransactions
                      .map((t) {
                        // Use the DateTime object directly
                        return DateTime(t.date.year, t.date.month, 1);
                      })
                      .toSet()
                      .toList()
                    ..sort((a, b) => b.compareTo(a));

              // Ensure _selectedMonth is a valid month from the data if it was not set or is no longer valid
              if (!allMonths.any(
                (month) => isSameMonth(_selectedMonth, month),
              )) {
                _selectedMonth =
                    allMonths.isNotEmpty ? allMonths.first : DateTime.now();
              }

              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: DropdownButton<DateTime>(
                  value: _selectedMonth,
                  dropdownColor: const Color(0xFFFAFAFA),
                  icon: const Icon(Icons.arrow_downward, color: Colors.white),
                  elevation: 16,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  underline: Container(height: 2, color: Colors.white),
                  onChanged: (DateTime? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedMonth = newValue;
                      });
                    }
                  },
                  items:
                      allMonths.map<DropdownMenuItem<DateTime>>((
                        DateTime month,
                      ) {
                        final isSelected = isSameMonth(_selectedMonth, month);
                        return DropdownMenuItem<DateTime>(
                          value: month,
                          child: Text(
                            DateFormat('MMMM yyyy').format(month),
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : const Color(0xFF333333),
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: StreamBuilder<List<Transaction>>(
        stream:
            _transactionService
                .getTransactions(), // Use the service to get the stream
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTransactions = snapshot.data ?? [];

          // Calculate overall balance from all transactions
          double overallBalance = 0;
          for (var transaction in allTransactions) {
            if (transaction.isExpense) {
              overallBalance -= transaction.amount;
            } else {
              overallBalance += transaction.amount;
            }
          }

          final monthlyTransactions = _getTransactionsForMonth(
            allTransactions,
            _selectedMonth,
          );
          final totalIncome = _getTotalIncome(monthlyTransactions);
          final totalExpenses = _getTotalExpenses(monthlyTransactions);
          final netCashFlow = totalIncome - totalExpenses;

          final expensesByCategory = _getExpensesByCategory(
            monthlyTransactions,
          );
          final totalMonthlyExpenses = totalExpenses;

          List<PieChartSectionData> pieChartSections =
              expensesByCategory.entries.map((entry) {
                final category = entry.key;
                final amount = entry.value;
                final percentage =
                    totalMonthlyExpenses == 0
                        ? 0
                        : (amount / totalMonthlyExpenses) * 100;

                return PieChartSectionData(
                  color:
                      Colors.primaries[expensesByCategory.keys.toList().indexOf(
                            category,
                          ) %
                          Colors.primaries.length],
                  value: amount,
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  titlePositionPercentageOffset: 0.55,
                );
              }).toList();

          final incomeVsExpensesData = _getIncomeVsExpensesForLast3Months(
            allTransactions,
            _selectedMonth,
          );
          final monthsForChart = incomeVsExpensesData.keys.toList();
          final incomeSpots =
              incomeVsExpensesData.entries.map((entry) {
                final index = monthsForChart.indexOf(entry.key);
                final data = entry.value;
                return FlSpot(index.toDouble(), data['income']!);
              }).toList();
          final expensesSpots =
              incomeVsExpensesData.entries.map((entry) {
                final index = monthsForChart.indexOf(entry.key);
                final data = entry.value;
                return FlSpot(index.toDouble(), data['expenses']!);
              }).toList();

          double rawMinY = 0;
          double rawMaxY = 0;
          if (incomeSpots.isNotEmpty || expensesSpots.isNotEmpty) {
            final allValues = [
              ...incomeSpots.map((spot) => spot.y),
              ...expensesSpots.map((spot) => spot.y),
            ];
            if (allValues.isNotEmpty) {
              rawMinY = allValues.reduce((a, b) => a < b ? a : b);
              rawMaxY = allValues.reduce((a, b) => a > b ? a : b);
            }
          }

          // Add some padding to the min/max Y values after calculating raw values
          double minY = rawMinY - (rawMaxY - rawMinY) * 0.1;
          double maxY = rawMaxY + (rawMaxY - rawMinY) * 0.1;

          // Handle case where minY and maxY are the same
          if (minY == maxY) {
            minY = minY < 0 ? minY * 1.2 : minY * 0.8; // Adjust based on sign
            maxY = maxY > 0 ? maxY * 1.2 : maxY * 0.8; // Adjust based on sign
            if (minY == maxY) {
              // If still the same (e.g., both are 0)
              minY = -100; // Default range
              maxY = 100;
            }
          }
          // Ensure minY is less than maxY
          if (minY > maxY) {
            final temp = minY;
            minY = maxY;
            maxY = temp;
          }


          if (allTransactions.isEmpty) {
            return const Center(
              child: Text(
                'No transactions available.',
                style: TextStyle(color: Color(0xFF333333)),
              ),
            );
          }

          return SingleChildScrollView(
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
                        const Text(
                          'Overall Balance',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '\$${overallBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            color:
                                overallBalance >= 0
                                    ? Colors.green[700]
                                    : const Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        Text(
                          'Total Income (${DateFormat('MMMM yyyy').format(_selectedMonth)})',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '\$${totalIncome.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        Text(
                          'Total Expenses (${DateFormat('MMMM yyyy').format(_selectedMonth)})',
                          style: TextStyle(
                            fontSize: 18,
                            color: const Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '\$${totalExpenses.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        Text(
                          'Net Cash Flow (${DateFormat('MMMM yyyy').format(_selectedMonth)})',
                          style: TextStyle(
                            fontSize: 18,
                            color: const Color(0xFF333333),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '\$${netCashFlow.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            color:
                                netCashFlow >= 0
                                    ? Colors.green[700]
                                    : const Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                // Income vs Expenses Line Chart
                Card(
                  color: const Color(0xFFFAFAFA),
                  elevation: 2.0,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 18.0,
                      left: 12.0,
                      top: 24,
                      bottom: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Income vs Expenses (Past 3 Months)',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        AspectRatio(
                          aspectRatio: 1.7,
                          child:
                              incomeVsExpensesData.isEmpty
                                  ? const Center(
                                    child: Text(
                                      'No data for the past 3 months.',
                                      style: TextStyle(
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  )
                                  : LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: true,
                                        horizontalInterval:
                                            (maxY - minY) /
                                            5, // Adjust interval dynamically
                                        verticalInterval: 1,
                                        getDrawingHorizontalLine: (value) {
                                          return const FlLine(
                                            color: Color(0xff37434d),
                                            strokeWidth: 1,
                                          );
                                        },
                                        getDrawingVerticalLine: (value) {
                                          return const FlLine(
                                            color: Color(0xff37434d),
                                            strokeWidth: 1,
                                          );
                                        },
                                      ),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 30,
                                            interval: 1,
                                            getTitlesWidget: (value, meta) {
                                              if (value.toInt() >= 0 &&
                                                  value.toInt() <
                                                      monthsForChart.length) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8.0,
                                                      ),
                                                  child: Text(
                                                    monthsForChart[value
                                                            .toInt()]
                                                        .split(' ')[0],
                                                    style: const TextStyle(
                                                      color: Color(0xff67727d),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return const Text('');
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: (maxY - minY) / 5,
                                            reservedSize: 40,
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                '\$${value.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: Color(0xff67727d),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(
                                          color: const Color(0xff37434d),
                                          width: 1,
                                        ),
                                      ),
                                      minX: 0,
                                      maxX:
                                          monthsForChart.isNotEmpty
                                              ? (monthsForChart.length - 1)
                                                  .toDouble()
                                              : 0, // Adjusted maxX
                                      minY: minY,
                                      maxY: maxY,
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: incomeSpots,
                                          isCurved: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.green.shade400,
                                              Colors.green.shade800,
                                            ],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                          barWidth: 2,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.green.shade400
                                                    .withOpacity(0.3),
                                                Colors.green.shade800
                                                    .withOpacity(0.3),
                                              ],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                          ),
                                        ),
                                        LineChartBarData(
                                          spots: expensesSpots,
                                          isCurved: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.red.shade400,
                                              Colors.red.shade800,
                                            ],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                          barWidth: 2,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.red.shade400.withOpacity(
                                                  0.3,
                                                ),
                                                Colors.red.shade800.withOpacity(
                                                  0.3,
                                                ),
                                              ],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('Income', Colors.green.shade600),
                    const SizedBox(width: 24.0),
                    _buildLegendItem('Expenses', Colors.red.shade600),
                  ],
                ),

                const SizedBox(height: 24.0),
                Card(
                  color: const Color(0xFFFAFAFA),
                  elevation: 2.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expenses by Category (${DateFormat('MMMM yyyy').format(_selectedMonth)})',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF333333),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        AspectRatio(
                          aspectRatio: 1.3,
                          child:
                              expensesByCategory.isEmpty
                                  ? const Center(
                                    child: Text(
                                      'No expenses for this month.',
                                      style: TextStyle(
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  )
                                  : PieChart(
                                    PieChartData(
                                      sections: pieChartSections,
                                      centerSpaceRadius: 40,
                                      sectionsSpace: 2,
                                      pieTouchData: PieTouchData(enabled: true),
                                    ),
                                  ),
                        ),
                        const SizedBox(height: 16.0),
                        Wrap(
                          spacing: 16.0,
                          runSpacing: 8.0,
                          children:
                              expensesByCategory.entries.map((entry) {
                                final category = entry.key;
                                final color =
                                    Colors.primaries[expensesByCategory.keys
                                            .toList()
                                            .indexOf(category) %
                                        Colors.primaries.length];
                                return _buildLegendItem(category, color);
                              }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                _buildMLInsightsSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}