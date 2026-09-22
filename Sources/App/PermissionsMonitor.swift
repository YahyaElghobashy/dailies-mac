import AppKit
import Foundation
import ServiceManagement
import UserNotifications
import WidgetKit

/// Live view of everything outside the app that Dailies depends on: notification permission,
/// whether the widget is actually placed on the desktop, and launch-at-login. Polls while the
/// Settings screen is visible so flipping a switch in System Settings shows up within seconds.
@MainActor
final class PermissionsMonitor: ObservableObject {
    enum Level { case ok, warn, off, unknown }

    @Published var notifStatus: UNAuthorizationStatus = .notDetermined
    @Published var widgets: [WidgetInfo] = []
    @Published var launchAtLogin = false
    @Published var lastChecked = Date()

    private var loop: Task<Void, Never>?

    func start() {
        stop()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    func refresh() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        notifStatus = s.authorizationStatus
        launchAtLogin = SMAppService.mainApp.status == .enabled
        widgets = await withCheckedContinuation { cont in
            WidgetCenter.shared.getCurrentConfigurations { result in
                cont.resume(returning: (try? result.get()) ?? [])
            }
        }
        lastChecked = Date()
    }

    // MARK: Notifications

    var notifText: String {
        switch notifStatus {
        case .authorized: return "Allowed"
        case .provisional: return "Allowed (delivered quietly)"
        case .denied: return "Denied — turn on in System Settings"
        case .notDetermined: return "Not asked yet"
        default: return "Unknown"
        }
    }

    var notifLevel: Level {
        switch notifStatus {
        case .authorized, .provisional: return .ok
        case .denied: return .off
        case .notDetermined: return .warn
        default: return .unknown
        }
    }

    func requestNotifications() {
        Task {
            _ = await Notifications.requestAuthorization()
            await refresh()
        }
    }

    func sendTestNotification() {
        let c = UNMutableNotificationContent()
        c.title = "Dailies is wired up 🔥"
        c.body = "This is what your reminders look like."
        c.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: c, trigger: trigger))
    }

    func openNotificationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.yahya.dailies")!)
    }

    // MARK: Widgets

    var widgetText: String {
        if widgets.isEmpty { return "Not on your desktop yet" }
        let names = widgets.map { familyName($0.family) }
        return "\(widgets.count) placed — " + names.joined(separator: ", ")
    }

    var widgetLevel: Level { widgets.isEmpty ? .warn : .ok }

    private func familyName(_ f: WidgetFamily) -> String {
        switch f {
        case .systemSmall: return "Small"
        case .systemMedium: return "Medium"
        case .systemLarge: return "Large"
        case .systemExtraLarge: return "Extra large"
        default: return "Other"
        }
    }

    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Login item

    func openLoginItemsSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
    }
}
