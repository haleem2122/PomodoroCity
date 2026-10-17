import Foundation
import UserNotifications

public class NotificationManager {
    public static let shared = NotificationManager()

    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }
    private let eveningReminderIdentifier = "pomodoro_city_evening_reminder"

    private init() {}

    public func requestAuthorization() {
        guard let center = center else { return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    public func sendFocusCompleteNotification() {
        guard let center = center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus Session Complete! 🏆"
        content.body = "Great work! Your city has gathered new building resources. Enjoy a well-deserved break."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    public func sendBreakCompleteNotification() {
        guard let center = center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Break Ended ☕️"
        content.body = "Ready to build more of your city? Start your next focus session whenever you are ready."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    public func sendStreakMilestoneNotification(days: Int) {
        guard let center = center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Streak Milestone Reached! 🔥"
        content.body = "Incredible! You have reached a \(days)-day focus streak in Pomodoro City!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// Schedules or updates the evening reminder if a session has not yet been completed today.
    public func updateEveningReminder(
        enabled: Bool,
        hour: Int,
        minute: Int,
        sessionCompletedToday: Bool,
        currentStreak: Int
    ) {
        guard let center = center else { return }

        // If disabled or if user already completed a session today, suppress the reminder
        guard enabled && !sessionCompletedToday else {
            cancelEveningReminder()
            return
        }

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Keep Your Streak Alive! 🔥"
        if currentStreak > 0 {
            content.body = "You have a \(currentStreak)-day streak at risk today. Complete a focus session to keep your city growing!"
        } else {
            content.body = "A quick focus session today will help your village thrive and start a new streak!"
        }
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: eveningReminderIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [eveningReminderIdentifier])
        center.add(request, withCompletionHandler: nil)
    }

    public func cancelEveningReminder() {
        guard let center = center else { return }
        center.removePendingNotificationRequests(withIdentifiers: [eveningReminderIdentifier])
    }
}
