import '../models/transaction.dart';

class CategoryInsight {
  final String category;
  final double amount;
  final double shareOfTotal; // 0..1
  CategoryInsight(this.category, this.amount, this.shareOfTotal);
}

class RecurringPayment {
  final String category;
  final String label;
  final double amount;
  final int occurrences;
  RecurringPayment({required this.category, required this.label, required this.amount, required this.occurrences});
}

class MonthComparison {
  final double thisMonth;
  final double lastMonth;
  double get changeAmount => thisMonth - lastMonth;
  double get changePercent => lastMonth == 0 ? 0 : (changeAmount / lastMonth) * 100;
  bool get isIncrease => changeAmount > 0;
  MonthComparison(this.thisMonth, this.lastMonth);
}

/// Turns a flat transaction list into the kind of "here's what's actually
/// going on" insights that separate a real finance app from a plain ledger:
/// where the money goes, whether spending is trending up or down, and which
/// payments repeat often enough to be worth flagging as recurring.
class InsightsService {
  static List<CategoryInsight> topCategories(List<Transaction> txs, {DateTime? month}) {
    final scoped = _scopeToMonth(txs.where((t) => t.type == TxType.expense).toList(), month);
    final totals = <String, double>{};
    for (final t in scoped) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    final total = totals.values.fold<double>(0, (s, v) => s + v);
    final list = totals.entries.map((e) => CategoryInsight(e.key, e.value, total == 0 ? 0 : e.value / total)).toList();
    list.sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  static MonthComparison monthOverMonth(List<Transaction> txs, {DateTime? month}) {
    final now = month ?? DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1);
    final thisTotal = _scopeToMonth(txs.where((t) => t.type == TxType.expense).toList(), now)
        .fold<double>(0, (s, t) => s + t.amount);
    final lastTotal = _scopeToMonth(txs.where((t) => t.type == TxType.expense).toList(), prevMonth)
        .fold<double>(0, (s, t) => s + t.amount);
    return MonthComparison(thisTotal, lastTotal);
  }

  /// Flags payments that look recurring: same category + a similar amount
  /// (within 10%) appearing 2+ times, roughly a month apart. Simple pattern
  /// match, not a subscription database — good enough to nudge "hey, this
  /// looks like a regular bill" without needing bank-level metadata.
  static List<RecurringPayment> detectRecurring(List<Transaction> txs) {
    final expenses = txs.where((t) => t.type == TxType.expense).toList()..sort((a, b) => a.date.compareTo(b.date));
    final groups = <String, List<Transaction>>{};
    for (final t in expenses) {
      final label = t.note.isNotEmpty ? t.note : t.category;
      final key = '${t.category}|${label.toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    final results = <RecurringPayment>[];
    groups.forEach((key, group) {
      if (group.length < 2) return;
      final amounts = group.map((t) => t.amount).toList();
      final avg = amounts.reduce((a, b) => a + b) / amounts.length;
      final withinTolerance = amounts.every((a) => (a - avg).abs() <= avg * 0.10);
      if (!withinTolerance) return;

      // Roughly monthly: gap between first and last / (count-1) is 20-40 days.
      final daysSpan = group.last.date.difference(group.first.date).inDays;
      final avgGap = group.length > 1 ? daysSpan / (group.length - 1) : 0;
      if (avgGap < 20 || avgGap > 40) return;

      final label = group.first.note.isNotEmpty ? group.first.note : group.first.category;
      results.add(RecurringPayment(category: group.first.category, label: label, amount: avg, occurrences: group.length));
    });
    results.sort((a, b) => b.amount.compareTo(a.amount));
    return results;
  }

  static List<Transaction> _scopeToMonth(List<Transaction> txs, DateTime? month) {
    if (month == null) return txs;
    return txs.where((t) => t.date.year == month.year && t.date.month == month.month).toList();
  }
}
