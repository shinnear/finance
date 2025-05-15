import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/goal.dart';
import '../services/goal_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final GoalService _goalService = GoalService();

  @override
  void initState() {
    super.initState();
    // Process automated savings on screen load
    _goalService.processMonthlySavings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals & Savings'),
        backgroundColor: const Color(0xFF333333),
      ),
      body: StreamBuilder<List<Goal>>(
        stream: _goalService.getGoals(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: \\${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final goals = snapshot.data ?? [];
          if (goals.isEmpty) {
            return const Center(child: Text('No goals yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              final progress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
              final now = DateTime.now();
              final monthsLeft = (goal.endDate.year - now.year) * 12 + (goal.endDate.month - now.month) + 1;
              final remaining = goal.targetAmount - goal.currentAmount;
              final monthlyAmount = monthsLeft > 0 ? (remaining / monthsLeft).clamp(0, remaining) : 0.0;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(goal.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showGoalDialog(goal: goal),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteGoal(goal),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (goal.description != null && goal.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(goal.description!, style: const TextStyle(color: Colors.grey)),
                        ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? Colors.green : Colors.blue)),
                      const SizedBox(height: 8),
                      Text('Saved: \\${goal.currentAmount.toStringAsFixed(2)} / \\${goal.targetAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                      Text('Monthly Saving Needed: \\${monthlyAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: Colors.blue)),
                      Text('Deadline: \\${DateFormat('MMM yyyy').format(goal.endDate)}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      if (goal.isCompleted)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text('Goal Completed!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalDialog(),
        backgroundColor: const Color(0xFF333333),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showGoalDialog({Goal? goal}) {
    final isEditing = goal != null;
    final titleController = TextEditingController(text: goal?.title ?? '');
    final targetAmountController = TextEditingController(text: goal?.targetAmount.toString() ?? '');
    final currentAmountController = TextEditingController(text: goal?.currentAmount.toString() ?? '0');
    final descriptionController = TextEditingController(text: goal?.description ?? '');
    DateTime startDate = goal?.startDate ?? DateTime.now();
    DateTime endDate = goal?.endDate ?? DateTime.now().add(const Duration(days: 180));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Goal' : 'Add Goal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: targetAmountController,
                      decoration: const InputDecoration(labelText: 'Target Amount'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: currentAmountController,
                      decoration: const InputDecoration(labelText: 'Current Amount'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Start Date:'),
                        const SizedBox(width: 8),
                        Text(DateFormat('yyyy-MM-dd').format(startDate)),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => startDate = picked);
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('End Date:'),
                        const SizedBox(width: 8),
                        Text(DateFormat('yyyy-MM-dd').format(endDate)),
                        IconButton(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: endDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => endDate = picked);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final targetAmount = double.tryParse(targetAmountController.text) ?? 0.0;
                    final currentAmount = double.tryParse(currentAmountController.text) ?? 0.0;
                    final description = descriptionController.text.trim();
                    if (title.isEmpty || targetAmount <= 0) return;
                    final newGoal = Goal(
                      id: goal?.id,
                      title: title,
                      targetAmount: targetAmount,
                      currentAmount: currentAmount,
                      startDate: startDate,
                      endDate: endDate,
                      description: description,
                      isCompleted: currentAmount >= targetAmount,
                      lastDeductionDate: goal?.lastDeductionDate,
                    );
                    if (isEditing) {
                      await _goalService.updateGoal(newGoal);
                    } else {
                      await _goalService.addGoal(newGoal);
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this goal?'),
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
      await _goalService.deleteGoal(goal.id!);
    }
  }
} 