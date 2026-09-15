import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/transaction.dart';

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
      await androidImpl?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
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
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_checkin',
    );
  }

  static Future<void> cancelDailyCheckin() async => _plugin.cancel(_dailyCheckinId);

  static const _dailyCheckinId = 9001;
}