import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

/// Uses method channel to interact with the native platform.
class IOSAlarm {
  // Private constructor
  IOSAlarm._privateConstructor() {
    print('IOSAlarm FLOW #Initializing IOSAlarm');
    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  // Static instance
  static final IOSAlarm _instance = IOSAlarm._privateConstructor();

  // Factory constructor
  factory IOSAlarm() {
    print('IOSAlarm FLOW #Creating instance');
    return _instance;
  }

  // Method channel for the alarm
  static const MethodChannel _methodChannel = MethodChannel('com.gdelataillade/alarm');
  static const EventChannel eventChannel = EventChannel("com.gdelataillade/events");

  // Map of alarm timers
  final Map<int, Timer?> timers = {};

  // Map of foreground/background subscriptions
  final Map<int, StreamSubscription<FGBGType>?> fgbgSubscriptions = {};


  // Handles incoming method calls from the native platform
  Future<void> _handleMethodCall(MethodCall call) async {
    print('IOSAlarm FLOW #Received method call: ${call.method} arguments: ${call.arguments}');

    final arguments = call.arguments as Map<dynamic, dynamic>;
    print('IOSAlarm FLOW #Received method arguments: $arguments');


    var id = call.arguments['id'] as int?;

    switch (call.method) {
      case 'alarmStoppedFromNotification':

        print('IOSAlarm FLOW #AEReceived alarmStoppedFromNotification: id=$id');
        break;
      case 'alarmSnoozedFromNotification':

        print('IOSAlarm FLOW #Received alarmSnoozedFromNotification: id=$id');
        break;
      case 'alarmConfirmedFromNotification':

        print('IOSAlarm FLOW #Received alarmConfirmedFromNotification: id=$id');
        break;
      default:
        throw MissingPluginException('notImplemented');
    }

    if (id != null) await Alarm().reload(id);
  }

  // Calls the native function `setAlarm` and listens to alarm ring state
  Future<bool> setAlarm(AlarmSettings settings) async {
    final id = settings.id;
    try {
      final res = await _methodChannel.invokeMethod<bool?>(
        'setAlarm',
        settings.toJson(),
      ) ??
          false;

      alarmPrint(
        '''Alarm with id $id scheduled ${res ? 'successfully' : 'failed'} at ${settings.dateTime}''',
      );

      if (!res) return false;
    } catch (e) {
      await Alarm().stop(id);
      throw AlarmException(e.toString());
    }

    if (timers[id] != null && timers[id]!.isActive) timers[id]!.cancel();
    timers[id] = periodicTimer(
          () => Alarm().ringStream.add(settings),
      settings.dateTime,
      id,
    );

    listenAppStateChange(
      id: id,
      onBackground: () => disposeTimer(id),
      onForeground: () async {
        if (fgbgSubscriptions[id] == null) return;

        final isRinging = await checkIfRinging(id);

        if (isRinging) {
          disposeAlarm(id);
          Alarm().ringStream.add(settings);
        } else {
          if (timers[id] != null && timers[id]!.isActive) timers[id]!.cancel();
          timers[id] = periodicTimer(
                () => Alarm().ringStream.add(settings),
            settings.dateTime,
            id,
          );
        }
      },
    );

    return true;
  }

  // Disposes timer and FGBG subscription and calls the native `stopAlarm` function
  Future<bool> stopAlarm(int id) async {
    disposeAlarm(id);
    print('Stopping alarm with id $id');
    final res = await _methodChannel.invokeMethod<bool?>(
      'stopAlarm',
      {'id': id},
    ) ??
        false;

    if (res) alarmPrint('Alarm with id $id stopped');

    return res;
  }

  // Returns the list of saved alarms stored locally
  Future<List<AlarmSettings>> getSavedAlarms() async {
    final res = await _methodChannel
        .invokeMethod<List<AlarmSettings>?>('getSavedAlarms') ??
        [];

    return res
        .map((e) => AlarmSettings.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Checks whether alarm is ringing by getting the native audio player's current time at two different moments
  Future<bool> checkIfRinging(int id) async {
    final pos1 = await _methodChannel
        .invokeMethod<double?>('audioCurrentTime', {'id': id}) ??
        0.0;
    await Future.delayed(const Duration(milliseconds: 100), () {});
    final pos2 = await _methodChannel
        .invokeMethod<double?>('audioCurrentTime', {'id': id}) ??
        0.0;

    return pos2 > pos1;
  }

  // Listens when app goes foreground so we can check if alarm is ringing
  void listenAppStateChange({
    required int id,
    required void Function() onForeground,
    required void Function() onBackground,
  }) {
    fgbgSubscriptions[id] = FGBGEvents.instance.stream.listen((event) {
      if (event == FGBGType.foreground) onForeground();
      if (event == FGBGType.background) onBackground();
    });
  }

  // Checks periodically if alarm is ringing, as long as app is in foreground
  Timer periodicTimer(void Function()? onRing, DateTime dt, int id) {
    return Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (DateTime.now().isBefore(dt)) return;
      disposeAlarm(id);
      onRing?.call();
    });
  }

  // Sets the native notification on app kill title and body
  Future<void> setWarningNotificationOnKill(String title, String body) =>
      _methodChannel.invokeMethod<void>(
        'setWarningNotificationOnKill',
        {'title': title, 'body': body},
      );

  // Disposes alarm timer
  void disposeTimer(int id) {
    timers[id]?.cancel();
    timers.removeWhere((key, value) => key == id);
  }

  // Disposes alarm timer and FGBG subscription
  void disposeAlarm(int id) {
    disposeTimer(id);
    fgbgSubscriptions[id]?.cancel();
    fgbgSubscriptions.removeWhere((key, value) => key == id);
  }
}
