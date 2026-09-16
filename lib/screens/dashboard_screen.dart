import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/local_store.dart';
import '../services/allocation_service.dart';
import '../theme/app_theme.dart';
import '../theme/category_icons.dart';
import 'add_transaction_screen.dart';
import 'allocate_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Budget> _budgets = [];
  Budget? _active;
  List<Transaction> _txs = [];
  List<Allocation> _allocations = [];
  String _userName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final budgets = await LocalStore.getBudgets();
    final activeId = await LocalStore.getActiveBudgetId();
    final txs = await LocalStore.getTransactions();
    final allocations = await LocalStore.getAllocations();
    final settings = await LocalStore.getSettings();
    setState(() {
      final name = (settings['name'] as String?)?.trim() ?? '';
      final email = (settings['email'] as String?)?.trim() ?? '';
      final emailUsername = email.contains('@') ? email.split('@').first : '';
      _userName = (name.isNotEmpty ? name : emailUsername).split(' ').first;
      _budgets = budgets;
      _active = budgets.firstWhere((b) => b.id == activeId, orElse: () => budgets.first);
      _txs = txs.where((t) => t.budgetId == _active!.id).toList()..sort((a, b) => b.date.compareTo(a.date));
      _allocations = allocations;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _active == null) return const Center(child: CircularProgressIndicator());

    final income = _txs.where((t) => t.type == TxType.income).fold<double>(0, (s, t) => s + t.amount - t.transactionFee);
    final expense = _txs.where((t) => t.type == TxType.expense).fold<double>(0, (s, t) => s + t.totalCost);
    final envelope = AllocationService.envelopeBalance(_allocations, _txs, _active!.id);
    final money = NumberFormat.decimalPattern();

    final now = DateTime.now();
    final monthExpense = _txs
        .where((t) => t.type == TxType.expense && t.date.month == now.month && t.date.year == now.year)
        .fold<double>(0, (s, t) => s + t.totalCost);
    final pct = _active!.monthlyLimit > 0 ? (monthExpense / _active!.monthlyLimit * 100).clamp(0, 100) : 0.0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? const [Color(0xFF1F2A7A), Color(0xFF6366F1)] : const [Color(0xFFE0E7FF), Color(0xFFCFD9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(), style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFFE0E7FF) : const Color(0xFF312E81), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_active!.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text("Here's where you stand", style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569))),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => AllocateScreen(budgets: _budgets, activeBudget: _active!)));
                        _load();
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: isDark ? 0.12 : 0.28),
                        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      icon: const Icon(Icons.pie_chart_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _statCard('Envelope balance', '${money.format(envelope)} ${_active!.currency}', envelope < 0 ? AppColors.negative : (isDark ? Colors.white : const Color(0xFF0F172A)), true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statCard('Income', '${money.format(income)} ${_active!.currency}', AppColors.positive, false)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Expenses', '${money.format(expense)} ${_active!.currency}', AppColors.negative, false)),
            ],
          ),
          if (_active!.monthlyLimit > 0) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("This month's spending", style: TextStyle(fontSize: 12.5, color: AppColors.mutedFor(context))),
                        Text('${money.format(monthExpense)} / ${money.format(_active!.monthlyLimit)} ${_active!.currency}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 8,
                        backgroundColor: AppColors.card2For(context),
                        color: pct >= 100 ? AppColors.negative : (pct >= 80 ? AppColors.warn : AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent transactions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              TextButton(onPressed: () {}, child: const Text('View all')),
            ],
          ),
          Card(
            child: _txs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 30, color: AppColors.mutedFor(context)),
                        const SizedBox(height: 10),
                        const Text('No transactions yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Add one manually, or send a MoMo message our way.', style: TextStyle(color: AppColors.mutedFor(context), fontSize: 12.5), textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          onPressed: () async {
                            final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
                            if (saved == true) _load();
                          },
                          child: const Text('Add transaction'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: _txs.take(8).map((t) => _txRow(t, money)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, bool isPrimary) => Card(
        color: isPrimary ? AppColors.accent.withValues(alpha: 0.12) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: AppColors.mutedFor(context))),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      );

  String _greeting() {
    final hour = DateTime.now().hour;
    final name = _userName.isEmpty ? 'there' : _userName;
    if (hour < 12) return 'Good morning, $name';
    if (hour < 17) return 'Good afternoon, $name';
    return 'Good evening, $name';
  }

  Widget _txRow(Transaction t, NumberFormat money) {
    final isIncome = t.type == TxType.income;
    final style = CategoryStyle.of(t.category);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIncome ? AppColors.positive.withValues(alpha: 0.15) : style.color.withValues(alpha: 0.15),
        child: Icon(isIncome ? Icons.arrow_upward : style.icon, color: isIncome ? AppColors.positive : style.color, size: 17),
      ),
      title: Text(t.note.isNotEmpty ? t.note : t.category, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${t.category} · ${DateFormat('dd MMM yyyy').format(t.date)}${t.source == 'sms-auto' ? ' · auto' : t.source == 'sms-paste' ? ' · pasted' : ''}',
        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isIncome ? '+' : '-'}${money.format(t.amount)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: isIncome ? AppColors.positive : AppColors.negative),
          ),
          if (t.fee != null)
            Text('Fee ${money.format(t.transactionFee)}', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ],
      ),
    );
  }
}
