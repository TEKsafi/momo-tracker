/// A configurable SMS source the user has told the app to watch — e.g. "MTN
/// MoMo", "Bank of Kigali", or any custom sender they add themselves. Only
/// messages from an ENABLED source's sender are ever handed to the parser;
/// everything else (personal texts, promotions, OTP codes) is ignored before
/// any parsing happens at all.
class MessageSource {
  final String id;
  String label;
  List<String> senderKeywords; // substrings matched against the SMS sender ID, case-insensitive
  bool enabled;
  final bool isBuiltIn; // built-ins (MoMo) can be toggled off but not deleted

  MessageSource({
    required this.id,
    required this.label,
    required this.senderKeywords,
    this.enabled = true,
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'senderKeywords': senderKeywords,
        'enabled': enabled,
        'isBuiltIn': isBuiltIn,
      };

  factory MessageSource.fromJson(Map<String, dynamic> j) => MessageSource(
        id: j['id'],
        label: j['label'],
        senderKeywords: (j['senderKeywords'] as List).map((e) => e.toString()).toList(),
        enabled: j['enabled'] ?? true,
        isBuiltIn: j['isBuiltIn'] ?? false,
      );

  /// Common Rwandan sources offered as one-tap add suggestions — not
  /// enabled by default (except MoMo), since we don't know which the user
  /// actually banks with.
  static List<MessageSource> defaults() => [
        MessageSource(id: 'momo', label: 'MTN MoMo', senderKeywords: ['M-Money', 'MTN', 'MoMo'], enabled: true, isBuiltIn: true),
        MessageSource(id: 'airtel', label: 'Airtel Money', senderKeywords: ['Airtel'], enabled: false, isBuiltIn: true),
        MessageSource(id: 'bk', label: 'Bank of Kigali', senderKeywords: ['BK', 'BankOfKigali'], enabled: false, isBuiltIn: true),
        MessageSource(id: 'equity', label: 'Equity Bank', senderKeywords: ['Equity'], enabled: false, isBuiltIn: true),
        MessageSource(id: 'im', label: 'I&M Bank', senderKeywords: ['I&M', 'IMBank'], enabled: false, isBuiltIn: true),
      ];
}
