import '../models/transaction.dart';

/// Result of parsing one MoMo SMS body. `null` fields mean "not found in
/// this message" — the UI should let the user fill gaps before saving.
class ParsedMomoMessage {
  final TxType? type;
  final double? amount;
  final String? counterparty;
  final double? balance;
  final double? fee;
  final String? momoTxId;
  final DateTime? date;
  final String rawText;

  ParsedMomoMessage({
    this.type,
    this.amount,
    this.counterparty,
    this.balance,
    this.fee,
    this.momoTxId,
    this.date,
    required this.rawText,
  });

  bool get isConfident => type != null && amount != null;
}

/// Parses MTN MoMo notification SMS text into structured data.
class MomoSmsParser {
  static final RegExp _amount = RegExp(r'([\d,]+(?:\.\d+)?)\s*RWF', caseSensitive: false);
  static final RegExp _balance = RegExp(r'new balance:?\s*([\d,]+(?:\.\d+)?)\s*RWF', caseSensitive: false);
  static final RegExp _fee = RegExp(r'Fee (?:was|paid)?:?\s*([\d,]+(?:\.\d+)?)\s*RWF', caseSensitive: false);
  static final RegExp _txId = RegExp(r'Financial Transaction Id:?\s*(\w+)', caseSensitive: false);
  static final RegExp _dateTime = RegExp(r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})');

  static final List<_Pattern> _patterns = [
    _Pattern(
      type: TxType.income,
      category: 'Other',
      regex: RegExp(r"received\s*([\d,]+(?:\.\d+)?)\s*RWF\s*from\s+([A-Za-z .'-]+?)(?:\s*\(|\s+on|\s+at)", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      category: 'Other',
      regex: RegExp(r"payment of\s*([\d,]+(?:\.\d+)?)\s*RWF\s*to\s+([A-Za-z0-9 .'-]+?)\s+has been", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      category: 'Other',
      regex: RegExp(r"transferred\s*([\d,]+(?:\.\d+)?)\s*RWF\s*to\s+([A-Za-z .'-]+?)(?:\s*\(|\s+at)", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      category: 'Other',
      regex: RegExp(r'withdrawn\s*([\d,]+(?:\.\d+)?)\s*RWF\s*from', caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      category: 'Airtime/Data',
      regex: RegExp(r'bought airtime for\s*([\d,]+(?:\.\d+)?)\s*RWF', caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      category: 'Airtime/Data',
      regex: RegExp(r'purchased bundles? for\s*([\d,]+(?:\.\d+)?)\s*RWF', caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      category: 'Other',
      regex: RegExp(r'debited (?:with)?\s*([\d,]+(?:\.\d+)?)\s*RWF', caseSensitive: false),
    ),
    _Pattern(
      type: TxType.income,
      category: 'Other',
      regex: RegExp(r'credited (?:with)?\s*([\d,]+(?:\.\d+)?)\s*RWF', caseSensitive: false),
    ),
  ];

  static double? _num(String? s) {
    if (s == null) return null;
    return double.tryParse(s.replaceAll(',', ''));
  }

  static ParsedMomoMessage parse(String text) {
    TxType? type;
    double? amount;
    String? party;
    String? category;

    for (final p in _patterns) {
      final m = p.regex.firstMatch(text);
      if (m != null) {
        type = p.type;
        amount = _num(m.group(1));
        category = p.category;
        if (m.groupCount >= 2) party = m.group(2)?.trim();
        break;
      }
    }

    amount ??= _num(_amount.firstMatch(text)?.group(1));

    DateTime? date;
    final dtMatch = _dateTime.firstMatch(text);
    if (dtMatch != null) {
      date = DateTime.tryParse(dtMatch.group(1)!.replaceFirst(' ', 'T'));
    }

    return ParsedMomoMessage(
      type: type,
      amount: amount,
      counterparty: party,
      balance: _num(_balance.firstMatch(text)?.group(1)),
      fee: _num(_fee.firstMatch(text)?.group(1)),
      momoTxId: _txId.firstMatch(text)?.group(1),
      date: date,
      rawText: text,
    );
  }

  static String guessCategory(ParsedMomoMessage parsed) {
    final t = parsed.rawText.toLowerCase();
    final party = (parsed.counterparty ?? '').toLowerCase();
    if (t.contains('airtime') || t.contains('bundle')) return 'Airtime/Data';
    if (party.contains('electro') || t.contains('electricity') || t.contains('rec ')) return 'Utilities';
    if (party.contains('restaurant') || party.contains('cafe') || party.contains('coffee') || party.contains('supermarket')) return 'Food';
    if (party.contains('moto') || party.contains('taxi') || t.contains('transport')) return 'Transport';
    if (parsed.type == TxType.income) return 'Other';
    return 'Other';
  }
}

class _Pattern {
  final TxType type;
  final String category;
  final RegExp regex;
  _Pattern({required this.type, required this.category, required this.regex});
}