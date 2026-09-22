import Foundation
import UserNotifications

enum Notifications {
    static let categoryID = "DAILIES_REMINDER"

    static let morningTitles = ["Your dailies are waiting ☀️", "Fresh puzzles just dropped", "New day, new streak fuel",
                                "Brain warm-up time", "The grid awaits"]
    static let eveningTitles = ["Streak at risk 🔥", "Don't let the flame die", "Last call for today's puzzles"]

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let open = UNNotificationAction(identifier: "OPEN", title: "Open Dailies", options: [.foreground])
        let cat = UNNotificationCategory(identifier: categoryID, actions: [open], intentIdentifiers: [], options: [])
        center.setNotificationCategories([cat])
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Re-plans the next 7 days of nudges from the current state. Called after every change,
    /// so a finished day never nags you.
    @MainActor
    static func reschedule(store: Store) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let s = store.settings
        guard s.remindersEnabled else { return }

        let now = Date()
        let today = store.today
        let status = store.todayStatus
        let streak = store.currentStreak
        let goal = store.dailyGoal
        guard goal > 0 else { return }

        for offset in 0..<7 {
            let day = DayKey.shift(today, by: offset)
            guard let base = DayKey.date(day) else { continue }
            let isToday = offset == 0
            if isToday, status.complete { continue }

            if let fire = Calendar.current.date(bySettingHour: s.morningHour, minute: s.morningMinute, second: 0, of: base), fire > now {
                let c = UNMutableNotificationContent()
                c.title = morningTitles.randomElement() ?? "Your dailies are waiting"
                c.body = isToday
                    ? "\(status.toGo) to go · \(streak)-day streak"
                    : "\(goal) games to hit your goal. Keep the streak alive."
                c.sound = .default
                c.categoryIdentifier = categoryID
                schedule(center, id: "morning-\(day)", content: c, at: fire)
            }

            if s.eveningEnabled,
               let fire = Calendar.current.date(bySettingHour: s.eveningHour, minute: s.eveningMinute, second: 0, of: base), fire > now {
                let c = UNMutableNotificationContent()
                c.title = eveningTitles.randomElement() ?? "Streak at risk 🔥"
                c.body = isToday
                    ? (streak > 0 ? "\(status.toGo) to go — don't lose the \(streak)-day streak." : "\(status.toGo) to go. Start a streak tonight.")
                    : "Still puzzles left today. A few minutes keeps the flame alive."
                c.sound = .default
                c.categoryIdentifier = categoryID
                c.interruptionLevel = .timeSensitive
                schedule(center, id: "evening-\(day)", content: c, at: fire)
            }
        }
    }

    private static func schedule(_ center: UNUserNotificationCenter, id: String, content: UNNotificationContent, at date: Date) {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
