import 'dart:convert';

enum TxType { income, expense }

class Transaction {
  final String id;
  final String budgetId;
  final TxType type;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final String source; // 'manual', 'sms-auto', 'sms-paste'
  final String? counterparty;
  final double? fee;
  final String? momoTxId;
  final String? accountId;

  Transaction({
    required this.id,
    required this.budgetId,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.source = 'manual',
    this.counterparty,
    this.fee,
    this.momoTxId,
    this.accountId,
  });

  double get transactionFee => fee ?? 0;

  /// The amount that changes the real MoMo balance for this transaction.
  double get cashImpact => type == TxType.income
      ? amount - transactionFee
      : -(amount + transactionFee);

  double get totalCost => type == TxType.expense ? amount + transactionFee : amount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'budgetId': budgetId,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'source': source,
        'counterparty': counterparty,
        'fee': fee,
        'momoTxId': momoTxId,
        'accountId': accountId,
      };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'],
        budgetId: j['budgetId'],
        type: j['type'] == 'income' ? TxType.income : TxType.expense,
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] ?? 'Other',
        note: j['note'] ?? '',
        date: DateTime.parse(j['date']),
        source: j['source'] ?? 'manual',
        counterparty: j['counterparty'],
        fee: j['fee'] == null ? null : (j['fee'] as num).toDouble(),
        momoTxId: j['momoTxId'],
        accountId: j['accountId'],
      );
}

class MoneyAccount {
  final String id;
  String name;
  String type;
  String currency;

  MoneyAccount({required this.id, required this.name, required this.type, this.currency = 'RWF'});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'currency': currency};

  factory MoneyAccount.fromJson(Map<String, dynamic> json) => MoneyAccount(
        id: json['id'],
        name: json['name'],
        type: json['type'] ?? 'other',
        currency: json['currency'] ?? 'RWF',
      );
}

class Budget {
  final String id;
  String name;
  String currency;
  double monthlyLimit;
  List<String> categories;

  Budget({
    required this.id,
    required this.name,
    this.currency = 'RWF',
    this.monthlyLimit = 0,
    List<String>? categories,
  }) : categories = categories ??
            ['Food', 'Transport', 'Rent', 'Utilities', 'Airtime/Data', 'Savings', 'Health', 'Entertainment', 'Education', 'Other'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currency': currency,
        'monthlyLimit': monthlyLimit,
        'categories': categories,
      };

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: j['id'],
        name: j['name'],
        currency: j['currency'] ?? 'RWF',
        monthlyLimit: (j['monthlyLimit'] as num?)?.toDouble() ?? 0,
        categories: (j['categories'] as List?)?.map((e) => e.toString()).toList(),
      );
}

/// A named "envelope" that lets a user allocate portions of one pooled
/// MoMo balance across budgets, since MoMo itself only tracks one balance.
class Allocation {
  final String id;
  final String budgetId;
  final double amount;
  final DateTime date;
  final String note;

  Allocation({required this.id, required this.budgetId, required this.amount, required this.date, this.note = ''});

  Map<String, dynamic> toJson() => {'id': id, 'budgetId': budgetId, 'amount': amount, 'date': date.toIso8601String(), 'note': note};

  factory Allocation.fromJson(Map<String, dynamic> j) => Allocation(
        id: j['id'],
        budgetId: j['budgetId'],
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date']),
        note: j['note'] ?? '',
      );
}

/// A savings target within a budget — e.g. "Emergency fund: 200,000 RWF by December".
class SavingsGoal {
  final String id;
  final String budgetId;
  String name;
  double targetAmount;
  double savedAmount;
  DateTime? targetDate;

  SavingsGoal({
    required this.id,
    required this.budgetId,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.targetDate,
  });

  double get progress => targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);
  double get remaining => (targetAmount - savedAmount).clamp(0, double.infinity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'budgetId': budgetId,
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'targetDate': targetDate?.toIso8601String(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
        id: j['id'],
        budgetId: j['budgetId'],
        name: j['name'],
        targetAmount: (j['targetAmount'] as num).toDouble(),
        savedAmount: (j['savedAmount'] as num?)?.toDouble() ?? 0,
        targetDate: j['targetDate'] == null ? null : DateTime.parse(j['targetDate']),
      );
}

String encodeList(List<dynamic> items) => jsonEncode(items.map((e) => e.toJson()).toList());
