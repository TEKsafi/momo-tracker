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

class MomoSmsParser {
  static final RegExp _amount = RegExp(r"([\d,]+(?:\.\d+)?)\s*RWF", caseSensitive: false);
  static final RegExp _balance = RegExp(r"(?:new )?balance\s*[:=]?\s*([\d,]+(?:\.\d+)?)\s*RWF", caseSensitive: false);
  static final RegExp _fee = RegExp(r"Fee\s*(?:was|paid)?\s*[:=]?\s*([\d,]+(?:\.\d+)?)\s*RWF", caseSensitive: false);
  static final RegExp _txId = RegExp(r"(?:Financial Transaction Id|TransactionId|TxId|FT\s+Id|ET\s+Id|Reference)\s*[:=]?\s*([A-Za-z0-9]+)", caseSensitive: false);
  static final RegExp _dateTime = RegExp(r"(\d{4}-\d{2}-\d{2}[T\s]+\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:?\d{2})?)");

  static final List<_Pattern> _patterns = [
    _Pattern(
      type: TxType.expense,
      regex: RegExp(r"A transaction of\s*([\d,]+(?:\.\d+)?)\s*RWF\s*by\s+(.+?)\s+(?:was completed|at)", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.income,
      regex: RegExp(r"received\s*([\d,]+(?:\.\d+)?)\s*RWF\s*from\s+([A-Za-z0-9 .'\'-]+?)(?:\s*\(|\s+on|\s+at|\.|,|$)", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      regex: RegExp(r"payment of\s*([\d,]+(?:\.\d+)?)\s*RWF\s*to\s+([A-Za-z0-9 .'\'-]+?)(?:\s+with token|\s+has been|\s+was completed|\s+at|\.|,|$)", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      regex: RegExp(r"m-money\s*:\s*.*?transferred\s*([\d,]+(?:\.\d+)?)\s*RWF\s*to\s+([A-Za-z0-9 .'\'-]+?)(?=\s*(?:\.|,|reference|balance|$))", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.income,
      regex: RegExp(r"m-money\s*:\s*.*?received\s*([\d,]+(?:\.\d+)?)\s*RWF\s*from\s+([A-Za-z0-9 .'\'-]+?)(?=\s*(?:\.|,|reference|balance|$))", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      regex: RegExp(r"([\d,]+(?:\.\d+)?)\s*RWF\s*transferred\s*to\s+([A-Za-z0-9 .'\'-]+?)(?:\s*\([^)]*\))?(?:\s+at|\.|,|$)", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      regex: RegExp(r"\btransferred\s*([\d,]+(?:\.\d+)?)\s*RWF\s*to\s+([A-Za-z0-9 .'\'-]+?)(?:\s*\([^)]*\))?(?:\s+at|\.|,|$)", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      regex: RegExp(r"withdrawn\s*([\d,]+(?:\.\d+)?)\s*RWF\s*from", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      regex: RegExp(r"bought airtime for\s*([\d,]+(?:\.\d+)?)\s*RWF", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.expense,
      regex: RegExp(r"(?:you have\s+)?(?:payment of|debit|debited)\s*([\d,]+(?:\.\d+)?)\s*RWF", caseSensitive: false),
    ),
    _Pattern(
      type: TxType.income,
      regex: RegExp(r"credited\s*(?:with\s*)?([\d,]+(?:\.\d+)?)\s*RWF", caseSensitive: false),
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

    for (final p in _patterns) {
      final match = p.regex.firstMatch(text);
      if (match != null) {
        type = p.type;
        amount = _num(match.group(1));
        if (match.groupCount >= 2) {
          party = match.group(2)?.trim();
        }
        break;
      }
    }

    amount ??= _num(_amount.firstMatch(text)?.group(1));

    DateTime? date;
    final dtMatch = _dateTime.firstMatch(text);
    if (dtMatch != null) {
      date = DateTime.tryParse(dtMatch.group(1)!.replaceFirst(' ', 'T'));
    }

    final refId = _txId.firstMatch(text)?.group(1) ?? _extractReferenceIdFromText(text);

    return ParsedMomoMessage(
      type: type,
      amount: amount,
      counterparty: party,
      balance: _num(_balance.firstMatch(text)?.group(1)),
      fee: _num(_fee.firstMatch(text)?.group(1)),
      momoTxId: refId,
      date: date,
      rawText: text,
    );
  }

  static String? _extractReferenceIdFromText(String text) {
    final match = RegExp(r"(?:reference|ref)\s*[:=]?\s*([A-Za-z0-9]+)", caseSensitive: false).firstMatch(text);
    return match?.group(1);
  }

  static String guessCategory(ParsedMomoMessage parsed) {
    final t = parsed.rawText.toLowerCase();
    final party = (parsed.counterparty ?? '').toLowerCase();
    if (t.contains('airtime') || t.contains('bundle')) return 'Airtime/Data';
    if (party.contains('electro') || t.contains('electricity') || t.contains('rec')) return 'Utilities';
    if (party.contains('restaurant') || party.contains('cafe') || party.contains('coffee') || party.contains('supermarket')) return 'Food';
    if (party.contains('moto') || party.contains('taxi') || t.contains('transport')) return 'Transport';
    if (parsed.type == TxType.income) return 'Other';
    return 'Other';
  }
}

class _Pattern {
  final TxType type;
  final RegExp regex;

  _Pattern({required this.type, required this.regex});
}