import UserNotifications

/// Schedules the optional daily workout reminder as a local notification.
enum ReminderScheduler {
    private static let identifier = "facefit.daily-reminder"

    /// Asks for permission if needed, then schedules the reminder. Returns false if notifications are denied.
    static func enable(minutesAfterMidnight: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        schedule(minutesAfterMidnight: minutesAfterMidnight)
        return true
    }

    static func schedule(minutesAfterMidnight: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Time for your face workout"
        content.body = "Five minutes today keeps your streak going."
        content.sound = .default

        var time = DateComponents()
        time.hour = minutesAfterMidnight / 60
        time.minute = minutesAfterMidnight % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger), withCompletionHandler: nil)
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
