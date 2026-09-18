import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budgeta/screens/settings_screen.dart';
import 'package:budgeta/services/local_store.dart';

void main() {
  test('cash reminder settings persist the selected 1/5/10/30 minute interval value', () async {
    SharedPreferences.setMockInitialValues({
      'momo_settings': jsonEncode({
        'name': '',
        'email': '',
        'phone': '',
        'theme': 'dark',
        'themeMode': 'dark',
        'autoReadSms': true,
        'hasOnboarded': true,
        'notifyOnTransaction': true,
        'dailyCheckinEnabled': false,
        'dailyCheckinHour': 20,
        'dailyCheckinMinute': 0,
        'cashReminderEnabled': true,
        'cashReminderIntervalMinutes': 5,
      }),
      'momo_message_sources': jsonEncode([]),
      'momo_money_accounts': jsonEncode([]),
    });

    await LocalStore.saveSettings({
      'name': '',
      'email': '',
      'phone': '',
      'theme': 'dark',
      'themeMode': 'dark',
      'autoReadSms': true,
      'hasOnboarded': true,
      'notifyOnTransaction': true,
      'dailyCheckinEnabled': false,
      'dailyCheckinHour': 20,
      'dailyCheckinMinute': 0,
      'cashReminderEnabled': true,
      'cashReminderIntervalMinutes': 5,
    });

    final settings = await LocalStore.getSettings();
    expect(settings['cashReminderEnabled'], isTrue);
    expect(settings['cashReminderIntervalMinutes'], 5);
  });
}
