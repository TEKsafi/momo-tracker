import 'dart:convert';

import '../models/message_source.dart';
import '../models/transaction.dart';
import 'local_store.dart';

class BackupService {
  static const _version = 1;

  static bool isValidPayload(Map<String, dynamic> payload) {
    if (payload['version'] is! int && payload['version'] is! String) return false;
    final requiredKeys = ['activeBudgetId', 'budgets', 'transactions', 'allocations', 'goals', 'accounts', 'sources', 'settings'];
    for (final key in requiredKeys) {
      if (!payload.containsKey(key)) return false;
    }
    return true;
  }

  static Future<Map<String, dynamic>> exportAll() async {
    final budgets = await LocalStore.getBudgets();
    final transactions = await LocalStore.getTransactions();
    final allocations = await LocalStore.getAllocations();
    final goals = await LocalStore.getSavingsGoals();
    final accounts = await LocalStore.getMoneyAccounts();
    final sources = await LocalStore.getMessageSources();
    final settings = await LocalStore.getSettings();
    final activeBudgetId = await LocalStore.getActiveBudgetId();

    return {
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'activeBudgetId': activeBudgetId,
      'budgets': budgets.map((b) => b.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'allocations': allocations.map((a) => a.toJson()).toList(),
      'goals': goals.map((g) => g.toJson()).toList(),
      'accounts': accounts.map((a) => a.toJson()).toList(),
      'sources': sources.map((s) => s.toJson()).toList(),
      'settings': settings,
    };
  }

  static Future<String> exportJson() async {
    final payload = await exportAll();
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Future<void> importAll(Map<String, dynamic> payload) async {
    if (!isValidPayload(payload)) {
      throw const FormatException('Invalid Budgeta backup schema. Expected version, activeBudgetId, budgets, transactions, allocations, goals, accounts, sources, and settings.');
    }

    final budgets = (payload['budgets'] as List? ?? [])
        .map((e) => Budget.fromJson(e as Map<String, dynamic>))
        .toList();
    final transactions = (payload['transactions'] as List? ?? [])
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
    final allocations = (payload['allocations'] as List? ?? [])
        .map((e) => Allocation.fromJson(e as Map<String, dynamic>))
        .toList();
    final goals = (payload['goals'] as List? ?? [])
        .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
        .toList();
    final accounts = (payload['accounts'] as List? ?? [])
        .map((e) => MoneyAccount.fromJson(e as Map<String, dynamic>))
        .toList();
    final sources = (payload['sources'] as List? ?? [])
        .map((e) => MessageSource.fromJson(e as Map<String, dynamic>))
        .toList();
    final settings = (payload['settings'] as Map<String, dynamic>?) ?? {};
    final activeBudgetId = (payload['activeBudgetId'] as String?) ?? (budgets.isNotEmpty ? budgets.first.id : '');

    await LocalStore.saveBudgets(budgets);
    await LocalStore.saveTransactions(transactions);
    await LocalStore.saveAllocations(allocations);
    await LocalStore.saveSavingsGoals(goals);
    await LocalStore.saveMoneyAccounts(accounts);
    await LocalStore.saveMessageSources(sources);
    await LocalStore.saveSettings(settings);
    if (activeBudgetId.isNotEmpty) {
      await LocalStore.setActiveBudgetId(activeBudgetId);
    }
  }
}
