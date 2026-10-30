import Foundation
import UserNotifications

enum Reminders {
    private static let workoutPrefix = "forge.workout."
    static let restID = "forge.rest"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Weekly reminders on each training day at the chosen time.
    static func sync(profile p: Profile) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (1...7).map { workoutPrefix + String($0) })
        guard p.remindersOn else { return }
        for wd in p.days {
            let content = UNMutableNotificationContent()
            content.title = "Time to train"
            content.body = "Your \(p.goal.label.lowercased()) workout is waiting. Let's go."
            content.sound = .default
            var dc = DateComponents()
            dc.weekday = wd
            dc.hour = p.reminderHour
            dc.minute = p.reminderMinute
            let req = UNNotificationRequest(identifier: workoutPrefix + String(wd), content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true))
            center.add(req)
        }
    }

    /// Fires when the rest timer ends, in case the app is in the background.
    static func scheduleRestEnd(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Rest's over"
        content.body = "Time for your next set."
        content.sound = .default
        let req = UNNotificationRequest(identifier: restID, content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false))
        UNUserNotificationCenter.current().add(req)
    }

    static func cancelRestEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restID])
    }
}

/// Shows notifications as banners even while the app is open (except the rest alert, which the in-app timer covers).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent n: UNNotification) async -> UNNotificationPresentationOptions {
        n.request.identifier == Reminders.restID ? [] : [.banner, .sound]
    }
}
