import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/local_store.dart';
import '../services/insights_service.dart';
import '../theme/app_theme.dart';
import '../theme/category_icons.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<Transaction> _txs = [];
  Budget? _budget;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final budgets = await LocalStore.getBudgets();
    final activeId = await LocalStore.getActiveBudgetId();
    final budget = budgets.firstWhere((b) => b.id == activeId, orElse: () => budgets.first);
    final txs = (await LocalStore.getTransactions()).where((t) => t.budgetId == budget.id).toList();
    setState(() {
      _budget = budget;
      _txs = txs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _budget == null) return const Center(child: CircularProgressIndicator());
    final money = NumberFormat.decimalPattern();
    final currency = _budget!.currency;

    final comparison = InsightsService.monthOverMonth(_txs);
    final topCats = InsightsService.topCategories(_txs, month: DateTime.now());
    final recurring = InsightsService.detectRecurring(_txs);

    if (_txs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            SizedBox(height: 80),
            Icon(Icons.insights_outlined, size: 40, color: AppColors.muted),
            SizedBox(height: 12),
            Text('Not enough data yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            SizedBox(height: 6),
            Text(
              'Log a few transactions and your spending patterns will show up here.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('This month vs last month', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Spent this month', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text('${money.format(comparison.thisMonth)} $currency', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: comparison.isIncrease ? AppColors.negative.withValues(alpha: 0.15) : AppColors.positive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(comparison.isIncrease ? Icons.trending_up : Icons.trending_down, size: 14, color: comparison.isIncrease ? AppColors.negative : AppColors.positive),
                        const SizedBox(width: 4),
                        Text(
                          '${comparison.changePercent.abs().toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: comparison.isIncrease ? AppColors.negative : AppColors.positive),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Where it went this month', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (topCats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No expenses logged this month yet.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            )
          else
            Card(
              child: Column(
                children: topCats.take(6).map((c) {
                  final style = CategoryStyle.of(c.category);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 15, backgroundColor: style.color.withValues(alpha: 0.15), child: Icon(style.icon, size: 15, color: style.color)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(c.category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text('${money.format(c.amount)} $currency', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(value: c.shareOfTotal, minHeight: 5, backgroundColor: AppColors.card2, color: style.color),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Icon(Icons.autorenew, size: 16, color: AppColors.accent),
              SizedBox(width: 6),
              Text('Payments that look recurring', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Detected from repeated amounts and timing — not official subscription data.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          if (recurring.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text("Nothing recurring detected yet — this builds up as you log more.", style: TextStyle(color: AppColors.muted, fontSize: 13)),
            )
          else
            Card(
              child: Column(
                children: recurring.map((r) {
                  final style = CategoryStyle.of(r.category);
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: style.color.withValues(alpha: 0.15), child: Icon(style.icon, size: 16, color: style.color)),
                    title: Text(r.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('Roughly monthly · seen ${r.occurrences} times', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    trailing: Text('~${money.format(r.amount)} $currency', style: const TextStyle(fontWeight: FontWeight.w700)),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
