import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgeta/models/transaction.dart';
import 'package:budgeta/services/local_store.dart';
import 'package:budgeta/services/momo_sms_parser.dart';

void main() {
  group('MomoSmsParser', () {
    test('parses a received-money message', () {
      final r = MomoSmsParser.parse(
        'You have received 5,000 RWF from John Doe (0788123456) on your mobile money account at 2026-09-10 14:23:00. Your new balance: 45,000 RWF. Financial Transaction Id: 123456789.',
      );
      expect(r.type, TxType.income);
      expect(r.amount, 5000);
      expect(r.counterparty, 'John Doe');
      expect(r.balance, 45000);
      expect(r.momoTxId, '123456789');
    });

    test('parses a merchant payment message', () {
      final r = MomoSmsParser.parse(
        'Your payment of 2,000 RWF to Kigali Coffee Shop has been completed at 2026-09-10 09:12:00. Your new balance: 43,000 RWF. Fee was 0 RWF. Financial Transaction Id: 987654321.',
      );
      expect(r.type, TxType.expense);
      expect(r.amount, 2000);
      expect(r.counterparty, 'Kigali Coffee Shop');
      expect(r.fee, 0);
    });

    test('parses a received transaction message with balance and FT id', () {
      final r = MomoSmsParser.parse(
        "*164*S*Y'ello, A transaction of 1,000 RWF by AC GROUP LTD AC GROUP LTD was completed at 2026-08-09 16:56:20. Balance:1536 RWF. Fee  0 RWF. FT Id: 29757221621. ET Id: 9160bdf0-8a24-4adc-8444-86fcb096790d.*RW#",
      );
      expect(r.type, TxType.income);
      expect(r.amount, 1000);
      expect(r.counterparty, 'AC GROUP LTD AC GROUP LTD');
      expect(r.balance, 1536);
      expect(r.fee, 0);
      expect(r.momoTxId, '29757221621');
    });

    test('parses a transfer with compact fee formatting', () {
      final r = MomoSmsParser.parse(
        '*165*S*500 RWF transferred to Jean Baptiste HABANABASHAKA (250786604299) at 2026-08-09 20:06:24 .Fee: 20RWF.Balance: 1016RWF.*RW#',
      );
      expect(r.type, TxType.expense);
      expect(r.amount, 500);
      expect(r.counterparty, 'Jean Baptiste HABANABASHAKA');
      expect(r.fee, 20);
      expect(r.balance, 1016);
    });

    test('parses ISO payment messages and includes fee in cash cost', () {
      final r = MomoSmsParser.parse(
        'TransactionId: 30013337577 Your payment of 180 RWF to SAFARI SIKUBWABO with token and ET Id: SUCCESSFUL at 2026-08-21T11:57:44.934+02:00.Fee:20 RWF. Balance 896 RWF.',
      );
      expect(r.type, TxType.expense);
      expect(r.amount, 180);
      expect(r.fee, 20);
      expect(r.momoTxId, '30013337577');
      expect(r.date, isNotNull);
      expect(Transaction(
        id: 'test', budgetId: 'test', type: TxType.expense, amount: r.amount!,
        category: 'Other', note: '', date: r.date!, fee: r.fee,
      ).totalCost, 200);
    });

    test('parses an agent withdrawal message', () {
      final r = MomoSmsParser.parse(
        'You have via agent Jean Agent withdrawn 10,000 RWF from your mobile money account at 2026-09-09 18:00:00. Your new balance: 33,000 RWF. Fee was 100 RWF.',
      );
      expect(r.type, TxType.expense);
      expect(r.amount, 10000);
      expect(r.fee, 100);
    });

    test('parses an airtime purchase and categorizes it', () {
      final r = MomoSmsParser.parse(
        'You have bought airtime for 1,000 RWF for 0788123456 at 2026-09-09 08:00:00. Your new balance: 32,000 RWF.',
      );
      expect(r.type, TxType.expense);
      expect(r.amount, 1000);
      expect(MomoSmsParser.guessCategory(r), 'Airtime/Data');
    });

    test('parses a transfer to a person', () {
      final r = MomoSmsParser.parse(
        'You have transferred 15,000 RWF to Marie Uwase (0788999888) at 2026-09-08 12:00:00. Your new balance: 17,000 RWF. Fee was 50 RWF.',
      );
      expect(r.type, TxType.expense);
      expect(r.amount, 15000);
      expect(r.counterparty, 'Marie Uwase');
    });

    test('creates default personal, business, and trip budgets', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalStore.seedIfEmpty();

      final budgets = await LocalStore.getBudgets();
      final names = budgets.map((b) => b.name.toLowerCase()).toList();

      expect(names, containsAll(['personal', 'business', 'trip']));
    });

    test('returns low-confidence result for unrelated text', () {
      final r = MomoSmsParser.parse('Hey, are we still meeting at 5pm today?');
      expect(r.isConfident, false);
    });
  });
}
