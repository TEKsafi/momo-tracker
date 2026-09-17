import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgeta/models/transaction.dart';
import 'package:budgeta/services/local_store.dart';
import 'package:budgeta/services/momo_sms_parser.dart';
import 'package:budgeta/services/notification_service.dart';

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

    test('parses a merchant transaction message with balance and FT id', () {
      final r = MomoSmsParser.parse(
        "*164*S*Y'ello, A transaction of 1,000 RWF by AC GROUP LTD AC GROUP LTD was completed at 2026-08-09 16:56:20. Balance:1536 RWF. Fee  0 RWF. FT Id: 29757221621. ET Id: 9160bdf0-8a24-4adc-8444-86fcb096790d.*RW#",
      );
      expect(r.type, TxType.expense);
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
      expect(r.counterparty, 'SAFARI SIKUBWABO');
      expect(r.balance, 896);
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

    test('parses the supplied outgoing payment and transfer formats', () {
      final messages = [
        (
          '*164*S*Y\'ello, A transaction of 250 RWF by AC GROUP LTD AC GROUP LTD was completed at 2026-09-04 15:33:29. Balance:26 RWF. Fee  0 RWF. FT Id: 30338942540. ET Id: f2fc7a12-085b-45ff-9649-7f275d61dee5.*RW#',
          250.0,
          0.0,
          26.0,
          'AC GROUP LTD AC GROUP LTD',
          '30338942540',
        ),
        (
          '*162*TxId:30324114844*S*Your payment of 23500 RWF to Mokash Savings with token  and ET Id: 20260903000000009037143482 was completed at 2026-09-03 20:51:47. Fee 0 RWF. Balance: 276 RWF .',
          23500.0,
          0.0,
          276.0,
          'Mokash Savings',
          '30324114844',
        ),
        (
          '*165*S*2500 RWF transferred to Chance James Emmanuel SHEMA (250788675241) at 2026-09-01 17:52:51 .Fee: 100RWF.Balance: 21276RWF.*RW#',
          2500.0,
          100.0,
          21276.0,
          'Chance James Emmanuel SHEMA',
          null,
        ),
        (
          'TxId:30253781431*S*Your payment of 520 RWF to Odette 17621 was completed at 2026-08-31 20:50:06.  Balance: 23,876 RWF. Fee 0 RWF.*EN#',
          520.0,
          0.0,
          23876.0,
          'Odette 17621',
          '30253781431',
        ),
        (
          '*165*S*500 RWF transferred to Jean Paul NDAYISENGA (250780973278) at 2026-08-31 20:28:32 .Fee: 20RWF.Balance: 24396RWF.*RW#',
          500.0,
          20.0,
          24396.0,
          'Jean Paul NDAYISENGA',
          null,
        ),
        (
          'TransactionId: 30252235128 Your payment of 6230 RWF to Shyaka foste with token and ET Id:  SUCCESSFUL at 2026-08-31T19:55:04.111+02:00.Fee:20 RWF. Balance 24916 RWF.',
          6230.0,
          20.0,
          24916.0,
          'Shyaka foste',
          '30252235128',
        ),
        (
          'TransactionId: 30247691472 Your payment of 30600 RWF to Denise UWINEZA with token and ET Id:  SUCCESSFUL at 2026-08-31T17:49:40.018+02:00.Fee:20 RWF. Balance 31166 RWF.',
          30600.0,
          20.0,
          31166.0,
          'Denise UWINEZA',
          '30247691472',
        ),
        (
          'TxId:30552904394*S*Your payment of 600 RWF to Chantal 1180006 was completed at 2026-09-14 07:32:26.  Balance: 36 RWF. Fee 0 RWF.*EN#',
          600.0,
          0.0,
          36.0,
          'Chantal 1180006',
          '30552904394',
        ),
      ];

      for (final message in messages) {
        final r = MomoSmsParser.parse(message.$1);
        expect(r.type, TxType.expense, reason: message.$1);
        expect(r.amount, message.$2, reason: message.$1);
        expect(r.fee, message.$3, reason: message.$1);
        expect(r.balance, message.$4, reason: message.$1);
        expect(r.counterparty, message.$5, reason: message.$1);
        if (message.$6 != null) expect(r.momoTxId, message.$6, reason: message.$1);
        expect(r.date, isNotNull, reason: message.$1);
      }
    });

    test('creates default personal, business, and trip budgets', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalStore.seedIfEmpty();

      final budgets = await LocalStore.getBudgets();
      final names = budgets.map((b) => b.name.toLowerCase()).toList();

      expect(names, containsAll(['personal', 'business', 'trip']));
    });

    test('builds a clear Budgeta notification summary for detected transactions', () {
      final parsed = MomoSmsParser.parse(
        'Your payment of 2,000 RWF to Kigali Coffee Shop has been completed at 2026-09-10 09:12:00. Your new balance: 43,000 RWF. Fee was 0 RWF. Financial Transaction Id: 987654321.',
      );

      final text = NotificationService.buildDetectedSummary(parsed, currency: 'RWF');
      expect(text, contains('2,000'));
      expect(text, contains('Kigali Coffee Shop'));
      expect(text, contains('Review'));
    });

    test('parses a direct M-Money transfer alert with reference ID and amount', () {
      final parsed = MomoSmsParser.parse(
        'M-Money: You have transferred 5,000 RWF to Jean Paul. Reference: 20260917TX1234. Balance: 18,000 RWF.',
      );

      expect(parsed.type, TxType.expense);
      expect(parsed.amount, 5000);
      expect(parsed.counterparty, 'Jean Paul');
      expect(parsed.momoTxId, '20260917TX1234');
    });

    test('parses a direct M-Money incoming money alert with reference ID', () {
      final parsed = MomoSmsParser.parse(
        'M-Money: You have received 10,000 RWF from Grace Mugisha. Reference: 20260917RX4321. Your balance: 40,000 RWF.',
      );

      expect(parsed.type, TxType.income);
      expect(parsed.amount, 10000);
      expect(parsed.counterparty, 'Grace Mugisha');
      expect(parsed.momoTxId, '20260917RX4321');
    });

    test('dedupes pending and saved MoMo transactions by reference ID', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalStore.seedIfEmpty();

      expect(await LocalStore.hasMomoTxId('REF-123'), isFalse);

      await LocalStore.rememberMomoTxId('REF-123');
      expect(await LocalStore.hasMomoTxId('REF-123'), isTrue);

      final tx = Transaction(
        id: 'tx-1',
        budgetId: 'budget-1',
        type: TxType.expense,
        amount: 5000,
        category: 'Other',
        note: 'Lunch',
        date: DateTime.now(),
        momoTxId: 'REF-123',
      );
      await LocalStore.addTransaction(tx);

      expect(await LocalStore.hasMomoTxId('REF-123'), isTrue);
    });

    test('returns low-confidence result for unrelated text', () {
      final r = MomoSmsParser.parse('Hey, are we still meeting at 5pm today?');
      expect(r.isConfident, false);
    });
  });
}
