import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../models/message_source.dart';

/// Local-first store so the app works fully offline and demonstrates the
/// data model end-to-end. Swap the body of each method for an ApiService
/// call once your Flask backend is ready — the method signatures are
/// designed to map 1:1 onto REST endpoints (see ApiService for the mirror).
class LocalStore {
  static const _kBudgets = 'momo_budgets';
  static const _kTransactions = 'momo_transactions';
  static const _kAllocations = 'momo_allocations';
  static const _kActiveBudget = 'momo_active_budget';
  static const _kSettings = 'momo_settings';
  static const _kGoals = 'momo_savings_goals';
  static const _kMessageSources = 'momo_message_sources';
  static const uuid = Uuid();

  static Future<void> seedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_kBudgets)) return;

    final personal = Budget(id: uuid.v4(), name: 'Personal', monthlyLimit: 50000);
    await prefs.setString(_kBudgets, jsonEncode([personal.toJson()]));
    await prefs.setString(_kActiveBudget, personal.id);
    await prefs.setString(_kTransactions, jsonEncode([]));
    await prefs.setString(_kAllocations, jsonEncode([]));
    await prefs.setString(_kGoals, jsonEncode([]));
    await prefs.setString(_kMessageSources, jsonEncode(MessageSource.defaults().map((s) => s.toJson()).toList()));
    await prefs.setString(_kSettings, jsonEncode({
      'name': 'Safari',
      'email': 'safari@example.com',
      'theme': 'dark',
      'autoReadSms': true,
      'hasOnboarded': false,
      'notifyOnTransaction': true,
      'dailyCheckinEnabled': false,
      'dailyCheckinHour': 20,
      'dailyCheckinMinute': 0,
    }));
  }

  static Future<List<Budget>> getBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBudgets) ?? '[]';
    return (jsonDecode(raw) as List).map((e) => Budget.fromJson(e)).toList();
  }

  static Future<void> saveBudgets(List<Budget> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBudgets, jsonEncode(budgets.map((b) => b.toJson()).toList()));
  }

  static Future<String> getActiveBudgetId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveBudget) ?? '';
  }

  static Future<void> setActiveBudgetId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveBudget, id);
  }

  static Future<List<Transaction>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kTransactions) ?? '[]';
    return (jsonDecode(raw) as List).map((e) => Transaction.fromJson(e)).toList();
  }

  static Future<void> saveTransactions(List<Transaction> txs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTransactions, jsonEncode(txs.map((t) => t.toJson()).toList()));
  }

  static Future<void> addTransaction(Transaction tx) async {
    final txs = await getTransactions();
    txs.add(tx);
    await saveTransactions(txs);
  }

  static Future<void> deleteTransaction(String id) async {
    final txs = await getTransactions();
    txs.removeWhere((t) => t.id == id);
    await saveTransactions(txs);
  }

  static Future<List<Allocation>> getAllocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAllocations) ?? '[]';
    return (jsonDecode(raw) as List).map((e) => Allocation.fromJson(e)).toList();
  }

  static Future<void> saveAllocations(List<Allocation> allocations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAllocations, jsonEncode(allocations.map((a) => a.toJson()).toList()));
  }

  static Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSettings) ?? '{}';
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, jsonEncode(settings));
  }

  static Future<List<SavingsGoal>> getSavingsGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGoals) ?? '[]';
    return (jsonDecode(raw) as List).map((e) => SavingsGoal.fromJson(e)).toList();
  }

  static Future<void> saveSavingsGoals(List<SavingsGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGoals, jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  static Future<List<MessageSource>> getMessageSources() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMessageSources);
    if (raw == null) {
      final defaults = MessageSource.defaults();
      await prefs.setString(_kMessageSources, jsonEncode(defaults.map((s) => s.toJson()).toList()));
      return defaults;
    }
    return (jsonDecode(raw) as List).map((e) => MessageSource.fromJson(e)).toList();
  }

  static Future<void> saveMessageSources(List<MessageSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMessageSources, jsonEncode(sources.map((s) => s.toJson()).toList()));
  }

  /// Have we already logged this MoMo transaction id? Prevents duplicate
  /// entries if the SMS listener fires twice for the same message.
  static Future<bool> hasMomoTxId(String momoTxId) async {
    final txs = await getTransactions();
    return txs.any((t) => t.momoTxId == momoTxId);
  }
}
