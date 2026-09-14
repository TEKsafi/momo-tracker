import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});
  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  List<SavingsGoal> _goals = [];
  String? _budgetId;
  String _currency = 'RWF';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final budgets = await LocalStore.getBudgets();
    final activeId = await LocalStore.getActiveBudgetId();
    final budget = budgets.firstWhere((b) => b.id == activeId, orElse: () => budgets.first);
    final goals = await LocalStore.getSavingsGoals();
    setState(() {
      _budgetId = budget.id;
      _currency = budget.currency;
      _goals = goals.where((g) => g.budgetId == budget.id).toList();
    });
  }

  Future<void> _createGoal() async {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New savings goal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('Goal name', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Emergency fund, New laptop')),
            const SizedBox(height: 14),
            const Text('Target amount', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(controller: targetController, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create goal'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final target = double.tryParse(targetController.text.trim()) ?? 0;
      if (target <= 0) return;
      final goals = await LocalStore.getSavingsGoals();
      goals.add(SavingsGoal(id: LocalStore.uuid.v4(), budgetId: _budgetId!, name: nameController.text.trim(), targetAmount: target));
      await LocalStore.saveSavingsGoals(goals);
      _load();
    }
  }

  Future<void> _addContribution(SavingsGoal goal) async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Add to goal', style: TextStyle(fontSize: 15)),
        content: TextField(controller: controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Amount')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.trim())), child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result > 0) {
      final goals = await LocalStore.getSavingsGoals();
      final target = goals.firstWhere((g) => g.id == goal.id);
      target.savedAmount += result;
      await LocalStore.saveSavingsGoals(goals);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      floatingActionButton: FloatingActionButton(onPressed: _createGoal, child: const Icon(Icons.add)),
      body: _goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.savings_outlined, size: 40, color: AppColors.muted),
                    const SizedBox(height: 12),
                    const Text('No goals yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Set a target — an emergency fund, a phone, a trip — and track it separately from everyday spending.', style: TextStyle(fontSize: 13, color: AppColors.muted), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _createGoal, child: const Text('Create your first goal')),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: _goals.map((g) {
                final pct = (g.progress * 100).toStringAsFixed(0);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(g.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                            Text('$pct%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(value: g.progress, minHeight: 8, backgroundColor: AppColors.card2, color: AppColors.accent),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${money.format(g.savedAmount)} of ${money.format(g.targetAmount)} $_currency', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            TextButton(onPressed: () => _addContribution(g), child: const Text('Add money')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
