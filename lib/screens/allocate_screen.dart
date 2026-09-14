import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/allocation_service.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';

class AllocateScreen extends StatefulWidget {
  final List<Budget> budgets;
  final Budget activeBudget;
  const AllocateScreen({super.key, required this.budgets, required this.activeBudget});

  @override
  State<AllocateScreen> createState() => _AllocateScreenState();
}

class _AllocateScreenState extends State<AllocateScreen> {
  final _amountController = TextEditingController();
  String? _targetBudgetId;
  List<Allocation> _allocations = [];
  List<Transaction> _txs = [];

  @override
  void initState() {
    super.initState();
    _targetBudgetId = widget.activeBudget.id;
    _load();
  }

  Future<void> _load() async {
    final allocations = await LocalStore.getAllocations();
    final txs = await LocalStore.getTransactions();
    setState(() {
      _allocations = allocations;
      _txs = txs;
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _targetBudgetId == null) return;
    await AllocationService.allocate(budgetId: _targetBudgetId!, amount: amount, note: 'Manual allocation');
    _amountController.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    return Scaffold(
      appBar: AppBar(title: const Text('Allocate money')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "MoMo only tracks one balance for your whole account. Allocating money here doesn't move real cash — it just tells this app which budget that money belongs to, so mixed funds stay organized on your side.",
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          const Text('Envelope balances', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...widget.budgets.map((b) {
            final bal = AllocationService.envelopeBalance(_allocations, _txs, b.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                trailing: Text('${money.format(bal)} ${b.currency}', style: TextStyle(fontWeight: FontWeight.w700, color: bal < 0 ? AppColors.negative : AppColors.text)),
              ),
            );
          }),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assign an amount to a budget', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const Text('Amount', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 14),
                  const Text('Assign to', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _targetBudgetId,
                    items: widget.budgets.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (v) => setState(() => _targetBudgetId = v),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _submit, child: const Text('Allocate')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
