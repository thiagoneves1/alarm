import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    private func setupNotificationActions(stopButton: String, snoozeButton: String, confirmButton: String) {
        var actions: [UNNotificationAction] = []
        
        let stopAction = UNNotificationAction(identifier: "STOP_ACTION", title: stopButton, options: [.destructive])
        actions.append(stopAction)

        let snoozeAction = UNNotificationAction(identifier: "SNOOZE_ACTION", title: snoozeButton, options:[.destructive])
        actions.append(snoozeAction)

        let confirmAction = UNNotificationAction(identifier: "CONFIRM_ACTION", title: confirmButton, options: [.destructive])
        actions.append(confirmAction)
        
        let category = UNNotificationCategory(identifier: "ALARM_CATEGORY", actions: actions, intentIdentifiers: [], options: [])
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }

    func scheduleNotification(id: Int, delayInSeconds: Int, notificationSettings: NotificationSettings, completion: @escaping (Error?) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                NSLog("[NotificationManager] Notification permission not granted. Cannot schedule alarm notification. Please request permission first.")
                let error = NSError(domain: "NotificationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification permission not granted"])
                completion(error)
                return
            }




            self.setupNotificationActions(
                stopButton: notificationSettings.stopButton ?? "",
                snoozeButton: notificationSettings.snoozeButton ?? "",
                confirmButton: notificationSettings.confirmButton ?? ""
            )

            let content = UNMutableNotificationContent()
            content.title = notificationSettings.title
            content.body = notificationSettings.body
            content.sound = nil
            content.categoryIdentifier = "ALARM_CATEGORY"
            content.userInfo = ["id": id]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayInSeconds), repeats: false)
            let request = UNNotificationRequest(identifier: "alarm-\(id)", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
        }
    }

    func cancelNotification(id: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["alarm-\(id)"])
    }

    func handleAction(withIdentifier identifier: String?, for notification: UNNotification) {

        guard let identifier = identifier else { return }
        guard let id = notification.request.content.userInfo["id"] as? Int else { return }

        NSLog("[NotificationManager] Handling action identifier: \(identifier) for notification: \(notification.request.identifier) AND ID \(id)")
        switch identifier {
        case "STOP_ACTION":
            SwiftAlarmPlugin.shared.unsaveAlarm(id: id)
            break;

         case "SNOOZE_ACTION":
            SwiftAlarmPlugin.shared.snoozeAlarm(id: id, result:  { _ in })
            break;

        case "CONFIRM_ACTION":
            SwiftAlarmPlugin.shared.confirmAlarm(id: id)
            break;

        default:
            break
        }
    }

    //This is called when a user interacts with a notification (taps it or takes an action)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        handleAction(withIdentifier: response.actionIdentifier, for: response.notification)
        completionHandler()
    }

    //This is called when a notification is about to be shown while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        NSLog("[NotificationManager] willPresent notification: \(notification.request.identifier)")
        completionHandler([.alert, .sound])
    }

//    func scheduleNotificationWithActions() {
//        let content = UNMutableNotificationContent()
//        content.title = "Meeting Reminder"
//        content.body = "Your meeting starts in 10 minutes!"
//        content.sound = UNNotificationSound.default
//
//        let action1 = UNNotificationAction(identifier: "snoozeAction", title: "Snooze", options: [])
//        let action2 = UNNotificationAction(identifier: "cancelAction", title: "Cancel", options: [.destructive])
//
//        let category = UNNotificationCategory(identifier: "meetingCategory", actions: [action1, action2], intentIdentifiers: [], options: [])
//
//        UNUserNotificationCenter.current().setNotificationCategories([category])
//
//        content.categoryIdentifier = "meetingCategory"
//
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
//
//        let request = UNNotificationRequest(identifier: "meetingNotification", content: content, trigger: trigger)
//
//        UNUserNotificationCenter.current().add(request) { error in
//            if let error = error {
//                print("Error scheduling notification: \(error.localizedDescription)")
//            } else {
//                print("Notification with actions scheduled successfully")
//            }
//        }
//    }
}