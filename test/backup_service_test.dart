import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgeta/models/transaction.dart';
import 'package:budgeta/services/backup_service.dart';
import 'package:budgeta/services/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService', () {
    test('exports and imports data without losing app state', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalStore.seedIfEmpty();

      final budgets = await LocalStore.getBudgets();
      final transactions = await LocalStore.getTransactions();
      final accounts = await LocalStore.getMoneyAccounts();

      final export = await BackupService.exportAll();

      await LocalStore.saveBudgets([
        Budget(id: 'temp', name: 'Imported Budget', currency: 'RWF', monthlyLimit: 1234),
      ]);
      await LocalStore.saveTransactions([]);
      await LocalStore.saveMoneyAccounts([
        MoneyAccount(id: 'temp-account', name: 'Imported account', type: 'bank'),
      ]);

      await BackupService.importAll(export);

      final restoredBudgets = await LocalStore.getBudgets();
      final restoredTransactions = await LocalStore.getTransactions();
      final restoredAccounts = await LocalStore.getMoneyAccounts();

      expect(restoredBudgets.length, budgets.length);
      expect(restoredTransactions.length, transactions.length);
      expect(restoredAccounts.length, accounts.length);
      expect(restoredBudgets.first.name, budgets.first.name);
    });
  });
}
