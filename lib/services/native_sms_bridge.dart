import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class NativeSmsBridge {
  static const MethodChannel _channel = MethodChannel('com.safari.budgeta/momo_sms');
  static const EventChannel _eventChannel = EventChannel('com.safari.budgeta/momo_sms_events');

  static Stream<Map<String, dynamic>>? _events;

  static Future<void> startListening({
    required void Function(Map<String, dynamic> payload) onMessage,
  }) async {
    if (!Platform.isAndroid) return;

    _events ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    });

    _events!.listen((payload) {
      onMessage(payload);
    });

    await _channel.invokeMethod('startListener');
  }

  static Future<void> stopListening() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('stopListener');
  }
}
