import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlarmEventReceiver {
  static const EventChannel _eventChannel = EventChannel('com.gdelataillade.alarm/events');
  static const methodChannel = MethodChannel('com.gdelataillade.alarm/alarm');

  void startListening() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final id = event['id'];
        final action = event['action'];
        // Handle the event based on the 'id' and 'method'
        print('#Received event: id=$id, action= $action');
      }
    }, onError: (error) {
      print('Error receiving event: $error');
    });
  }



  void recoveryIntents(BuildContext context) async {
    print('Recovering intents...');
    try {
      await methodChannel.invokeMethod(
        'getHistoryIntents',
      ).then((value) {
        print('Received intents: $value');
      });
    } catch (e) {
      print('Error recovering intents: $e');
    }
  }
}
