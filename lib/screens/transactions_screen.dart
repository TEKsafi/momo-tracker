import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/local_store.dart';
import '../theme/app_theme.dart';
import '../theme/category_icons.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Transaction> _all = [];
  String _filter = 'all';
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final activeId = await LocalStore.getActiveBudgetId();
    final txs = await LocalStore.getTransactions();
    setState(() {
      _all = txs.where((t) => t.budgetId == activeId).toList()..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<void> _delete(String id) async {
    await LocalStore.deleteTransaction(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.decimalPattern();
    var filtered = _filter == 'all' ? _all : _all.where((t) => t.type.name == _filter).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      filtered = filtered.where((t) => t.note.toLowerCase().contains(q) || t.category.toLowerCase().contains(q)).toList();
    }
    final hasActiveFilter = _filter != 'all' || _query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by note or category',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                _chip('all', 'All'),
                const SizedBox(width: 8),
                _chip('income', 'Income'),
                const SizedBox(width: 8),
                _chip('expense', 'Expenses'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off, size: 32, color: AppColors.darkMuted),
                          const SizedBox(height: 10),
                          Text(
                            hasActiveFilter ? 'Nothing matches' : 'No transactions yet',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasActiveFilter ? 'Try a different search term or filter.' : 'Add one manually, or send a MoMo message our way.',
                            style: const TextStyle(color: AppColors.darkMuted, fontSize: 12.5),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final t = filtered[i];
                      final isIncome = t.type == TxType.income;
                      final style = CategoryStyle.of(t.category);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome ? AppColors.positive.withValues(alpha: 0.15) : style.color.withValues(alpha: 0.15),
                          child: Icon(isIncome ? Icons.arrow_upward : style.icon, color: isIncome ? AppColors.positive : style.color, size: 17),
                        ),
                        title: Text(t.note.isNotEmpty ? t.note : t.category, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: Text('${t.category} · ${DateFormat('dd MMM yyyy').format(t.date)}', style: const TextStyle(fontSize: 11.5, color: AppColors.darkMuted)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${isIncome ? '+' : '-'}${money.format(t.amount)}', style: TextStyle(fontWeight: FontWeight.w700, color: isIncome ? AppColors.positive : AppColors.negative)),
                                if (t.fee != null)
                                  Text('Fee ${money.format(t.transactionFee)}', style: const TextStyle(fontSize: 10, color: AppColors.darkMuted)),
                              ],
                            ),
                            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.darkMuted), onPressed: () => _delete(t.id)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String value, String label) => ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      );
}
