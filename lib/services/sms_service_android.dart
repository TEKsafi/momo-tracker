import 'dart:io';
import 'package:telephony/telephony.dart';
import '../models/transaction.dart';
import 'momo_sms_parser.dart';
import 'local_store.dart';

/// Automatic SMS reading — Android only. On iOS this class's methods are
/// no-ops; iOS has no API for third-party SMS access (see ShareIntentService
/// for the iOS equivalent flow).
///
/// Requires these permissions in android/app/src/main/AndroidManifest.xml
/// (already added in this project — see that file):
///   android.permission.RECEIVE_SMS
///   android.permission.READ_SMS
class SmsService {
  static final Telephony _telephony = Telephony.instance;

  /// Senders to treat as MoMo. Extend this list if your MoMo texts arrive
  /// under a different sender ID than "M-Money" / "MTN".
  static const List<String> momoSenderKeywords = ['M-Money', 'MTN', 'MoMo'];

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    final granted = await _telephony.requestPhoneAndSmsPermissions;
    return granted ?? false;
  }

  static bool _looksLikeMomo(String? address) {
    if (address == null) return false;
    return momoSenderKeywords.any((k) => address.toLowerCase().contains(k.toLowerCase()));
  }

  /// Call once at app startup (Android only) to start listening for new
  /// incoming MoMo SMS while the app is running.
  static Future<void> startListening({required Future<void> Function(Transaction) onNewTransaction}) async {
    if (!isSupported) return;
    final granted = await requestPermissions();
    if (!granted) return;

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await _handleMessage(message.address, message.body, onNewTransaction);
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
    if (body == null || !_looksLikeMomo(address)) return false;

    final parsed = MomoSmsParser.parse(body);
    if (!parsed.isConfident) return false; // couldn't confidently parse — leave for manual review

    if (parsed.momoTxId != null && await LocalStore.hasMomoTxId(parsed.momoTxId!)) {
      return false; // already logged, avoid duplicates
    }

    final activeBudgetId = await LocalStore.getActiveBudgetId();
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
    );
    await LocalStore.addTransaction(tx);
    await onNewTransaction(tx);
    return true;
  }
}
