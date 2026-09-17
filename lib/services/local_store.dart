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
  static const _kMoneyAccounts = 'momo_money_accounts';
  static const _kNativeSmsQueue = 'momo_native_sms_queue';
  static const _kSeenMomoTxIds = 'momo_seen_reference_ids';
  static const uuid = Uuid();

  static Future<void> seedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_kBudgets)) return;

    final personal = Budget(id: uuid.v4(), name: 'Personal', monthlyLimit: 50000);
    final business = Budget(id: uuid.v4(), name: 'Business', monthlyLimit: 0);
    final trip = Budget(id: uuid.v4(), name: 'Trip', monthlyLimit: 0);

    final budgets = [personal, business, trip];
    await prefs.setString(_kBudgets, jsonEncode(budgets.map((b) => b.toJson()).toList()));
    await prefs.setString(_kActiveBudget, personal.id);
    await prefs.setString(_kTransactions, jsonEncode([]));
    await prefs.setString(_kAllocations, jsonEncode([]));
    await prefs.setString(_kGoals, jsonEncode([]));
    await prefs.setString(_kMessageSources, jsonEncode(MessageSource.defaults().map((s) => s.toJson()).toList()));
    await prefs.setString(_kMoneyAccounts, jsonEncode([
      MoneyAccount(id: uuid.v4(), name: 'MTN MoMo', type: 'mobile money').toJson(),
      MoneyAccount(id: uuid.v4(), name: 'Cash on hand', type: 'cash').toJson(),
    ]));
    await prefs.setString(_kSettings, jsonEncode({
      'name': '',
      'email': '',
      'phone': '',
      'theme': 'dark',
      'themeMode': 'dark',
      'autoReadSms': true,
      'hasOnboarded': false,
      'notifyOnTransaction': true,
      'dailyCheckinEnabled': false,
      'dailyCheckinHour': 20,
      'dailyCheckinMinute': 0,
      'cashReminderEnabled': false,
      'cashReminderIntervalMinutes': 60,
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
    if ((tx.momoTxId ?? '').trim().isNotEmpty) {
      await rememberMomoTxId(tx.momoTxId!);
    }

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
    final settings = jsonDecode(raw) as Map<String, dynamic>;
    var changed = false;
    if (settings['name'] == 'Safari') {
      settings['name'] = '';
      changed = true;
    }
    if (settings['email'] == 'safari@example.com') {
      settings['email'] = '';
      changed = true;
    }
    if (!settings.containsKey('phone')) {
      settings['phone'] = '';
      changed = true;
    }
    if (changed) await saveSettings(settings);
    return settings;
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, jsonEncode(settings));
  }

  static Future<List<MoneyAccount>> getMoneyAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMoneyAccounts);
    if (raw == null) {
      final defaults = [MoneyAccount(id: uuid.v4(), name: 'MTN MoMo', type: 'mobile money'), MoneyAccount(id: uuid.v4(), name: 'Cash on hand', type: 'cash')];
      await saveMoneyAccounts(defaults);
      return defaults;
    }
    return (jsonDecode(raw) as List).map((e) => MoneyAccount.fromJson(e)).toList();
  }

  static Future<void> saveMoneyAccounts(List<MoneyAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMoneyAccounts, jsonEncode(accounts.map((a) => a.toJson()).toList()));
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

  static Future<List<Map<String, dynamic>>> getNativeSmsQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNativeSmsQueue) ?? '[]';
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> saveNativeSmsQueue(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNativeSmsQueue, jsonEncode(entries));
  }

  static Future<void> addNativeSmsDebugEntry(Map<String, dynamic> entry) async {
    final queue = await getNativeSmsQueue();
    queue.add({
      ...entry,
      'loggedAt': DateTime.now().toIso8601String(),
    });
    if (queue.length > 200) {
      queue.removeRange(0, queue.length - 200);
    }
    await saveNativeSmsQueue(queue);
  }

  static Future<List<String>> getSeenMomoTxIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kSeenMomoTxIds) ?? const [];
    return ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
  }

  static Future<void> rememberMomoTxId(String momoTxId) async {
    final ref = momoTxId.trim();
    if (ref.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = await getSeenMomoTxIds();
    if (!seen.contains(ref)) {
      seen.add(ref);
      await prefs.setStringList(_kSeenMomoTxIds, seen);
    }
  }

  /// Have we already logged this MoMo transaction id? Prevents duplicate
  /// entries if the SMS listener fires twice for the same message.
  static Future<bool> hasMomoTxId(String momoTxId) async {
    final ref = momoTxId.trim();
    if (ref.isEmpty) return false;

    final seen = await getSeenMomoTxIds();
    if (seen.contains(ref)) return true;

    final txs = await getTransactions();
    return txs.any((t) => (t.momoTxId ?? '').trim() == ref);
  }
}
