import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/transaction.dart';
import 'momo_sms_parser.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _transactionChannel = AndroidNotificationDetails(
    'transactions',
    'Transaction alerts',
    channelDescription: 'Notifies you when a transaction is automatically logged',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _checkinChannel = AndroidNotificationDetails(
    'daily_checkin',
    'Daily cash check-in',
    channelDescription: 'A daily reminder to log any cash transactions by hand',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _cashReminderId = 9002;
  static const _cashReminderChannel = AndroidNotificationDetails(
    'cash_reminders',
    'Cash reminders',
    channelDescription: 'Reminds you to record cash transactions',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  static const _scheduledDarwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static Future<void> init({
    required void Function() onTapCheckin,
    void Function(ParsedMomoMessage parsed)? onTapDetectedTransaction,
  }) async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _setDeviceTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'daily_checkin') {
          onTapCheckin();
          return;
        }

        final payload = response.payload ?? '';
        if (payload.startsWith('sms_review:')) {
          final rawText = Uri.decodeComponent(payload.substring('sms_review:'.length));
          final parsed = MomoSmsParser.parse(rawText);
          onTapDetectedTransaction?.call(parsed);
        }
      },
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  static void _setDeviceTimezone() {
    final now = DateTime.now();
    tz.setLocalLocation(tz.Location(
      'device',
      const <int>[],
      const <int>[],
      [tz.TimeZone(now.timeZoneOffset.inMilliseconds, isDst: false, abbreviation: now.timeZoneName)],
    ));
  }

  static String buildDetectedSummary(ParsedMomoMessage parsed, {required String currency}) {
    final amount = parsed.amount ?? 0;
    final formatted = NumberFormat.decimalPattern().format(amount);
    final amountText = '$formatted $currency';
    final counterparty = parsed.counterparty?.trim().isNotEmpty == true ? parsed.counterparty!.trim() : 'MoMo transaction';
    final direction = parsed.type == TxType.income ? 'Received' : 'Spent';
    return 'Review: $direction $amountText • $counterparty';
  }

  static Future<void> notifyDetectedTransaction(ParsedMomoMessage parsed, {required String currency}) async {
    final isIncome = parsed.type == TxType.income;
    final title = isIncome ? 'Budgeta: Money received' : 'Budgeta: Review transaction';
    final body = buildDetectedSummary(parsed, currency: currency);
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: _transactionChannel),
      payload: 'sms_review:${Uri.encodeComponent(parsed.rawText)}',
    );
  }

  static Future<void> notifyTransactionLogged(Transaction tx, String currency) async {
    final isIncome = tx.type == TxType.income;
    final amountText = '${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} $currency';
    final title = isIncome ? 'Money received' : 'Transaction logged';
    final body = tx.note.isNotEmpty ? '$amountText · ${tx.note}' : '$amountText · ${tx.category}';

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: _transactionChannel),
    );
  }

  static Future<void> scheduleDailyCheckin({required int hour, required int minute}) async {
    await _plugin.cancel(_dailyCheckinId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _dailyCheckinId,
      'Did you spend or receive cash today?',
      "Log anything that didn't come through as a text — takes a few seconds.",
      scheduled,
      const NotificationDetails(android: _checkinChannel, iOS: _scheduledDarwinDetails, macOS: _scheduledDarwinDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_checkin',
    );
  }

  static Future<void> cancelDailyCheckin() async => _plugin.cancel(_dailyCheckinId);

  static Future<void> scheduleCashReminder({required int intervalMinutes}) async {
    await _plugin.cancel(_cashReminderId);
    final repeat = intervalMinutes <= 1
        ? RepeatInterval.everyMinute
        : intervalMinutes <= 60
            ? RepeatInterval.hourly
            : RepeatInterval.daily;
    await _plugin.periodicallyShow(
      _cashReminderId,
      'Record cash on hand',
      'Did you spend or receive cash? Add it before you forget.',
      repeat,
      const NotificationDetails(android: _cashReminderChannel, iOS: _scheduledDarwinDetails, macOS: _scheduledDarwinDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'daily_checkin',
    );
  }

  static Future<void> cancelCashReminder() async => _plugin.cancel(_cashReminderId);

  static const _dailyCheckinId = 9001;
}