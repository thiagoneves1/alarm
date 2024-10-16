import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlarmEventReceiver {
  static final EventChannel _eventChannel = Platform.isIOS ? const EventChannel('com.gdelataillade/events') :
    const EventChannel('com.gdelataillade.alarm/events');
  static final methodChannel = Platform.isIOS ? const MethodChannel('com.gdelataillade/alarm')
      : const MethodChannel('com.gdelataillade.alarm/alarm');

  void startListening() {
    print('Starting to listen to events...');
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final id = event['id'];
        final action = event['action'];
        // Handle the event based on the 'id' and 'method'
        print('#FLOW #Received listening event: id=$id, action= $action');
      }
    }, onError: (error) {
      print('Error receiving event: $error');
    });

    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'alarmStoppedFromNotification':
        var id = call.arguments['id'];
        print('#FLOW #Received alarmStoppedFromNotification: id=$id');
        break;
      default:
        throw MissingPluginException('notImplemented');
    }
  }



  void recoveryIntents(BuildContext context) async {
    print('Recovering intents...');
    try {
      await methodChannel.invokeMethod(
        'getHistoryIntents',
      ).then((value) {
        print('#Received recovery intents: $value');
      });
    } catch (e) {
      print('Error recovering intents: $e');
    }
  }
}
