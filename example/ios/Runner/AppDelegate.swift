import UIKit
import Flutter
import UserNotifications
import alarm

@main
@objc class AppDelegate: FlutterAppDelegate {
private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    SwiftAlarmPlugin.registerBackgroundTasks()


    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(name: "com.thiagoneves.alarm", binaryMessenger: controller.binaryMessenger)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
          NSLog("[AppDelegate] didReceive response: \(response)")

          let userInfo = response.notification.request.content.userInfo
              guard let id = userInfo["id"] as? Int else {
                  completionHandler()
                  return
              }

              switch response.actionIdentifier {
              case "STOP_ACTION":
                  NSLog("[AppDelegate] STOP_ACTION ")
                  SwiftAlarmPlugin.testStopFromAppDelegate()
                  methodChannel?.invokeMethod("stopAlarm", arguments: ["id": id])
                  break;

               case "SNOOZE_ACTION":
                  NSLog("[AppDelegate] SNOOZE_ACTION")
                  SwiftAlarmPlugin.testSnoozeFromAppDelegate()
                  methodChannel?.invokeMethod("snoozeAlarm", arguments: ["id": id])
                  break;

              case "CONFIRM_ACTION":
                  NSLog("[AppDelegate] CONFIRM_ACTION ")
                  methodChannel?.invokeMethod("confirmAlarm", arguments: ["id": id])
                  break;
              default:
                  // Handle default action
                   NSLog("[AppDelegate] Default ")
                  break
          }

          completionHandler()
      }

      override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
          // Handle foreground presentation options
          completionHandler([.alert, .sound, .badge])
      }
}
