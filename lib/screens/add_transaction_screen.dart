import 'dart:io';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/local_store.dart';
import '../services/momo_sms_parser.dart';
import '../theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  final ParsedMomoMessage? initialParsed;
  final String? initialBudgetId;
  final String? initialSource;

  const AddTransactionScreen({super.key, this.initialParsed, this.initialBudgetId, this.initialSource});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _pasteController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TxType _type = TxType.expense;
  String? _category;
  String? _budgetId;
  List<String> _categories = ['Other'];
  List<Budget> _budgets = const [];
  List<MoneyAccount> _accounts = const [];
  String? _accountId;
  DateTime _date = DateTime.now();
  ParsedMomoMessage? _lastParsed;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.initialParsed != null) {
      _applyParsed(widget.initialParsed!);
    }
  }

  Future<void> _loadCategories() async {
    final budgets = await LocalStore.getBudgets();
    final accounts = await LocalStore.getMoneyAccounts();
    final activeId = widget.initialBudgetId ?? await LocalStore.getActiveBudgetId();
    final active = budgets.firstWhere((b) => b.id == activeId, orElse: () => budgets.first);
    setState(() {
      _budgets = budgets;
      _budgetId = active.id;
      _categories = active.categories;
      _category = active.categories.first;
      _accounts = accounts;
      _accountId = accounts.isEmpty ? null : accounts.first.id;
    });
  }

  void _applyParsed(ParsedMomoMessage parsed) {
    setState(() {
      _lastParsed = parsed;
      if (parsed.amount != null) _amountController.text = parsed.amount!.toStringAsFixed(0);
      if (parsed.type != null) _type = parsed.type!;
      if (parsed.counterparty != null) _noteController.text = parsed.counterparty!;
      _category = MomoSmsParser.guessCategory(parsed);
      if (parsed.date != null) _date = parsed.date!;
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }

    final selectedBudgetId = _budgetId ?? await LocalStore.getActiveBudgetId();
    if (_budgetId != null) {
      await LocalStore.setActiveBudgetId(_budgetId!);
    }

    final tx = Transaction(
      id: LocalStore.uuid.v4(),
      budgetId: selectedBudgetId,
      type: _type,
      amount: amount,
      category: _category ?? 'Other',
      note: _noteController.text.trim(),
      date: _date,
      source: widget.initialSource ?? (_lastParsed != null ? 'sms-paste' : 'manual'),
      counterparty: _lastParsed?.counterparty,
      fee: _lastParsed?.fee,
      momoTxId: _lastParsed?.momoTxId,
      accountId: _accountId,
    );
    await LocalStore.addTransaction(tx);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // iOS-friendly manual capture: paste a MoMo message and auto-fill the form.
          Card(
            color: AppColors.card2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sms_outlined, size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        Platform.isIOS ? 'Paste a MoMo message' : 'Paste or share a MoMo message',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Platform.isIOS
                        ? "iOS doesn't allow apps to read SMS automatically — long-press the MoMo text in Messages, Copy, then paste it here."
                        : 'Paste a message here to auto-fill the form below, or just let auto-read handle it.',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pasteController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Paste MoMo SMS text here…'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () {
                        final text = _pasteController.text.trim();
                        if (text.isEmpty) return;
                        final parsed = MomoSmsParser.parse(text);
                        if (!parsed.isConfident) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't recognize that message — fill the form manually.")));
                          return;
                        }
                        _applyParsed(parsed);
                      },
                      child: const Text('Parse message'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Expense')),
                  selected: _type == TxType.expense,
                  selectedColor: AppColors.negative.withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _type = TxType.expense),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Income')),
                  selected: _type == TxType.income,
                  selectedColor: AppColors.positive.withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _type = TxType.income),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Amount', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 16),
          const Text('Budget', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _budgetId,
            items: _budgets.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
            onChanged: (v) {
              if (v == null) return;
              final selected = _budgets.firstWhere((b) => b.id == v, orElse: () => _budgets.first);
              setState(() {
                _budgetId = v;
                _categories = selected.categories;
                _category = selected.categories.first;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text('Money source', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _accountId,
            items: _accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
            onChanged: (value) => setState(() => _accountId = value),
          ),
          const SizedBox(height: 16),
          const Text('Category', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
          const Text('Note', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          TextField(controller: _noteController, decoration: const InputDecoration(hintText: 'e.g. Lunch with friends')),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _save, child: const Text('Save transaction')),
        ],
      ),
    );
  }
}
