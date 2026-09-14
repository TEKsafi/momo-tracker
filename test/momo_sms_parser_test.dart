import 'package:flutter_test/flutter_test.dart';
import 'package:momo_tracker/models/transaction.dart';
import 'package:momo_tracker/services/momo_sms_parser.dart';

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

    test('returns low-confidence result for unrelated text', () {
      final r = MomoSmsParser.parse('Hey, are we still meeting at 5pm today?');
      expect(r.isConfident, false);
    });
  });
}
