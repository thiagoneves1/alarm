// ignore_for_file: avoid_print

import 'dart:async';

import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/service/alarm_storage.dart';
import 'package:alarm/src/android_alarm.dart';
import 'package:alarm/src/ios_alarm.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:alarm/utils/extensions.dart';
import 'package:flutter/foundation.dart';

export 'package:alarm/model/alarm_settings.dart';
export 'package:alarm/model/notification_settings.dart';

/// Custom print function designed for Alarm plugin.
DebugPrintCallback alarmPrint = debugPrintThrottled;

/// Class that handles the alarm.
class Alarm {
  // Private constructor
  Alarm._privateConstructor();

  // Static instance
  static final Alarm _instance = Alarm._privateConstructor();

  // Factory constructor
  factory Alarm() {
    return _instance;
  }

  // Whether it's iOS device.
  bool get iOS => defaultTargetPlatform == TargetPlatform.iOS;

  // Whether it's Android device.
  bool get android => defaultTargetPlatform == TargetPlatform.android;

  // Stream of the alarm updates.
  final updateStream = StreamController<int>();

  // Stream of the ringing status.
  final ringStream = StreamController<AlarmSettings>();

  // Initializes Alarm services.
  Future<void> init({bool showDebugLogs = true}) async {
    alarmPrint = (String? message, {int? wrapWidth}) {
      if (showDebugLogs) print('[Alarm] $message');
    };

    if (android) AndroidAlarm.init();
    if (iOS) IOSAlarm();
    await AlarmStorage.init();

    await checkAlarm();
  }

  // Checks if some alarms were set on previous session.
  Future<void> checkAlarm() async {
    final alarms = getAlarms();

    if (iOS) await stopAll();

    for (final alarm in alarms) {
      final now = DateTime.now();
      if (alarm.dateTime.isAfter(now)) {
        await set(alarmSettings: alarm);
      } else {
        final isRinging = await this.isRinging(alarm.id);
        isRinging ? ringStream.add(alarm) : await stop(alarm.id);
      }
    }
  }

  // Schedules an alarm with given alarmSettings with its notification.
  Future<bool> set({required AlarmSettings alarmSettings}) async {
    alarmSettingsValidation(alarmSettings);

    for (final alarm in getAlarms()) {
      if (alarm.id == alarmSettings.id ||
          alarm.dateTime.isSameSecond(alarmSettings.dateTime)) {
        await stop(alarm.id);
      }
    }

    await AlarmStorage.saveAlarm(alarmSettings);

    if (iOS) return IOSAlarm().setAlarm(alarmSettings);
    if (android) return AndroidAlarm.set(alarmSettings);

    updateStream.add(alarmSettings.id);

    return false;
  }

  // Validates alarmSettings fields.
  void alarmSettingsValidation(AlarmSettings alarmSettings) {
    if (alarmSettings.id == 0 || alarmSettings.id == -1) {
      throw AlarmException(
        'Alarm id cannot be 0 or -1. Provided: ${alarmSettings.id}',
      );
    }
    if (alarmSettings.id > 2147483647) {
      throw AlarmException(
        'Alarm id cannot be set larger than Int max value (2147483647). Provided: ${alarmSettings.id}',
      );
    }
    if (alarmSettings.id < -2147483648) {
      throw AlarmException(
        'Alarm id cannot be set smaller than Int min value (-2147483648). Provided: ${alarmSettings.id}',
      );
    }
    if (alarmSettings.volume != null &&
        (alarmSettings.volume! < 0 || alarmSettings.volume! > 1)) {
      throw AlarmException(
        'Volume must be between 0 and 1. Provided: ${alarmSettings.volume}',
      );
    }
    if (alarmSettings.fadeDuration < 0) {
      throw AlarmException(
        'Fade duration must be positive. Provided: ${alarmSettings.fadeDuration}',
      );
    }
  }

  // When the app is killed, all the processes are terminated
  // so the alarm may never ring. By default, to warn the user, a notification
  // is shown at the moment he kills the app.
  // This methods allows you to customize this notification content.
  void setWarningNotificationOnKill(String title, String body) {
    if (iOS) IOSAlarm().setWarningNotificationOnKill(title, body);
    if (android) AndroidAlarm.setWarningNotificationOnKill(title, body);
  }

  // Stops alarm.
  Future<bool> stop(int id) async {
    await AlarmStorage.unsaveAlarm(id);
    updateStream.add(id);

    return iOS ? await IOSAlarm().stopAlarm(id) : await AndroidAlarm.stop(id);
  }

  // Stops all the alarms.
  Future<void> stopAll() async {
    final alarms = getAlarms();

    for (final alarm in alarms) {
      await stop(alarm.id);
    }
  }

  // Whether the alarm is ringing.
  Future<bool> isRinging(int id) async => iOS
      ? await IOSAlarm().checkIfRinging(id)
      : await AndroidAlarm.isRinging(id);

  // Whether an alarm is set.
  bool hasAlarm() => AlarmStorage.hasAlarm();

  // Returns alarm by given id. Returns null if not found.
  AlarmSettings? getAlarm(int id) {
    final alarms = getAlarms();

    for (final alarm in alarms) {
      if (alarm.id == id) return alarm;
    }
    alarmPrint('Alarm with id $id not found.');

    return null;
  }

  // Returns all the alarms.
  List<AlarmSettings> getAlarms() => AlarmStorage.getSavedAlarms();

  // Reloads the shared preferences instance in the case modifications
  // were made in the native code, after a notification action.
  Future<void> reload(int id) async {
    await AlarmStorage.prefs.reload();
    updateStream.add(id);
  }
}
