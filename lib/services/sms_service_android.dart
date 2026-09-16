import 'dart:io';
import 'package:telephony/telephony.dart';
import '../models/transaction.dart';
import 'momo_sms_parser.dart';
import 'local_store.dart';
import 'notification_service.dart';

/// Automatic SMS reading — Android only. On iOS this class's methods are
/// no-ops; iOS has no API for third-party SMS access (see ShareIntentService
/// for the iOS equivalent flow).
///
/// Which senders count as a transaction source is now configurable by the
/// user (Settings > Message sources, backed by LocalStore.getMessageSources)
/// instead of a fixed list — a message only gets parsed if it comes from a
/// source the user has explicitly enabled.
///
/// Requires these permissions in android/app/src/main/AndroidManifest.xml
/// (already added in this project — see that file):
///   android.permission.RECEIVE_SMS
///   android.permission.READ_SMS
class SmsService {
  static final Telephony _telephony = Telephony.instance;

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    final granted = await _telephony.requestPhoneAndSmsPermissions;
    return granted ?? false;
  }

  static Future<bool> _matchesEnabledSource(String? address) async {
    if (address == null) return false;
    final sources = await LocalStore.getMessageSources();
    final addressLower = address.toLowerCase();
    for (final source in sources) {
      if (!source.enabled) continue;
      for (final keyword in source.senderKeywords) {
        if (addressLower.contains(keyword.toLowerCase())) return true;
      }
    }
    return false;
  }

  /// Call once at app startup (Android only) to start listening for new
  /// incoming SMS from any enabled source while the app is running.
  static Future<void> startListening({required Future<void> Function(ParsedMomoMessage parsed) onParsedMessage}) async {
    if (!isSupported) return;
    final granted = await requestPermissions();
    if (!granted) return;

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        if (message.body == null || !await _matchesEnabledSource(message.address)) return;

        final parsed = MomoSmsParser.parse(message.body!);
        if (!parsed.isConfident) return;

        if (parsed.momoTxId != null && await LocalStore.hasMomoTxId(parsed.momoTxId!)) return;

        await onParsedMessage(parsed);
      },
      listenInBackground: false, // set true + configure a background handler for always-on capture
    );
  }

  /// One-off scan of existing inbox — useful the first time the app is
  /// installed, to backfill history instead of only catching future texts.
  static Future<int> importExistingInbox({required Future<void> Function(Transaction) onNewTransaction}) async {
    if (!isSupported) return 0;
    final granted = await requestPermissions();
    if (!granted) return 0;

    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    int imported = 0;
    for (final m in messages) {
      if (await _handleMessage(m.address, m.body, onNewTransaction)) imported++;
    }
    return imported;
  }

  static Future<bool> _handleMessage(String? address, String? body, Future<void> Function(Transaction) onNewTransaction) async {
    if (body == null || !await _matchesEnabledSource(address)) return false;

    final parsed = MomoSmsParser.parse(body);
    if (!parsed.isConfident) return false; // couldn't confidently parse — leave for manual review

    if (parsed.momoTxId != null && await LocalStore.hasMomoTxId(parsed.momoTxId!)) {
      return false; // already logged, avoid duplicates
    }

    final activeBudgetId = await LocalStore.getActiveBudgetId();
    final accounts = await LocalStore.getMoneyAccounts();
    final tx = Transaction(
      id: LocalStore.uuid.v4(),
      budgetId: activeBudgetId,
      type: parsed.type!,
      amount: parsed.amount!,
      category: MomoSmsParser.guessCategory(parsed),
      note: parsed.counterparty ?? '',
      date: parsed.date ?? DateTime.now(),
      source: 'sms-auto',
      counterparty: parsed.counterparty,
      fee: parsed.fee,
      momoTxId: parsed.momoTxId,
        accountId: accounts.where((a) => a.type == 'mobile money').isEmpty
          ? null
          : accounts.where((a) => a.type == 'mobile money').first.id,
    );
    await LocalStore.addTransaction(tx);
    await onNewTransaction(tx);

    final settings = await LocalStore.getSettings();
    if (settings['notifyOnTransaction'] == true) {
      final budgets = await LocalStore.getBudgets();
      final budget = budgets.firstWhere((b) => b.id == activeBudgetId, orElse: () => budgets.first);
      await NotificationService.notifyTransactionLogged(tx, budget.currency);
    }

    return true;
  }
}
