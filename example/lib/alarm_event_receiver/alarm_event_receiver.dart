import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlarmEventReceiver {
  static final EventChannel _eventChannel = Platform.isIOS ? const EventChannel('com.gdelataillade/events') :
    const EventChannel('com.gdelataillade.alarm/events');
  static final _methodChannel = Platform.isIOS ? const MethodChannel('com.gdelataillade/alarm')
      : const MethodChannel('com.gdelataillade.alarm/alarm');

  Stream<dynamic>? _eventStream;

  Stream<dynamic> get eventStream {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      print('#AER FLOW Received raw event: $event');
      return event;
    });
    return _eventStream!;
  }

  void startListening() async {
    print('#AER FLOW Starting to listen to events...');

    eventStream.listen(
          (event) {
        print('#AER FLOW Received event: $event');
        if (event is List) {
          for (var action in event) {
            if (action is Map) {
              final id = action['id'];
              final actionType = action['action'];
              final timestamp = action['timestamp'];
              print('#AER FLOW Received action: id=$id, action=$actionType, timestamp=$timestamp');
            }
          }
        }
      },
      onError: (error) {
        print('#AER FLOW Error receiving event: $error');
      },
    );

    try {
      final result = await _methodChannel.invokeMethod<bool>('getHistoryIntents');
      print('#AER FLOW History fetch result: $result');
    } catch (e) {
      print('#AER FLOW Error fetching history: $e');
    }

    _eventChannel.receiveBroadcastStream().listen((event) {
      print('#AER FLOW Received event: $event');
      if (event is Map) {
        final id = event['id'];
        final action = event['action'];
        // Handle the event based on the 'id' and 'method'
        print('#AER FLOW #Received listening event: id=$id, action= $action');
      }
    }, onError: (error) {
      print('#AER Error receiving event: $error');
    });

    final res = _methodChannel.invokeMethod<bool?>("getHistoryIntents").then((value) {
      print('#AER Listening started: $value');
    });
    print('#AER Listening started: $res');

    _methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'alarmStoppedFromNotification':
        var id = call.arguments['id'];
        print('#AER FLOW #AEReceived alarmStoppedFromNotification: id=$id');
        break;
      case 'alarmSnoozedFromNotification':
        var id = call.arguments['id'];
        print('#AER FLOW #Received alarmSnoozedFromNotification: id=$id');
        break;
      case 'alarmConfirmedFromNotification':
        var id = call.arguments['id'];
        print('#AER FLOW #Received alarmConfirmedFromNotification: id=$id');
        break;
      default:
        throw MissingPluginException('notImplemented');
    }
  }



  void recoveryIntents(BuildContext context) async {
    print('#AER Recovering intents...');
    try {
      await _methodChannel.invokeMethod(
        'getHistoryIntents',
      ).then((value) {
        print('#AER Received recovery intents: $value');
      });
    } catch (e) {
      print('#AER Error recovering intents: $e');
    }
  }
}
