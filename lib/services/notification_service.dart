import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/transaction.dart';

/// Two kinds of notifications this app sends:
/// 1. Instant: "a transaction was just logged" — fires right after SMS
///    auto-read or a share/paste import succeeds.
/// 2. Scheduled: a once-daily reminder asking the user to add any cash
///    transactions that never generated an SMS at all (e.g. handing someone
///    physical cash), so the app doesn't quietly miss those.
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

  /// Call once at app startup. [onTapCheckin] fires when the user taps the
  /// daily check-in notification specifically, so main.dart can navigate to
  /// the check-in screen.
  static Future<void> init({required void Function() onTapCheckin}) async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'daily_checkin') onTapCheckin();
      },
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission(); // Android 13+ runtime permission
    } else if (Platform.isIOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<DarwinFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
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

  /// Schedules (or reschedules) the daily check-in for [hour]:[minute] local
  /// time, repeating every day. Uses an inexact trigger so it doesn't need
  /// Android's separate "exact alarm" permission — a reminder landing a few
  /// minutes off schedule is fine for this use case.
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
      const NotificationDetails(android: _checkinChannel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily at this time
      payload: 'daily_checkin',
    );
  }

  static Future<void> cancelDailyCheckin() async => _plugin.cancel(_dailyCheckinId);

  static const _dailyCheckinId = 9001;
}
