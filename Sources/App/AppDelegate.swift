import AppKit
import UserNotifications
import WidgetKit

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let launchedAt = Date()
    private var lastActivation = Date.distantPast

    func applicationWillFinishLaunching(_ notification: Notification) {
        SuiteFlags.early()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SuiteFlags.handle()
        UNUserNotificationCenter.current().delegate = self

        // The widget extension toggles games in its own process; pick those changes up live.
        DistributedNotificationCenter.default().addObserver(forName: .dailiesStateChanged, object: nil, queue: .main) { _ in
            Task { @MainActor in Store.shared.refreshFromDisk() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in Store.shared.refreshFromDisk() }
        }

        Task { @MainActor in
            _ = await Notifications.requestAuthorization()
            Store.shared.rescheduleNotifications()
            Store.shared.syncLaunchAtLogin()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Widget links (play / toggle) should never throw the dashboard over the desktop: if the link
        // woke us — cold launch, or we only just became active — do the work and hide again.
        let cold = Date().timeIntervalSince(launchedAt) < 4
        let quiet = !urls.isEmpty && urls.allSatisfy { ["play", "toggle"].contains($0.host?.lowercased() ?? "") }
        Task { @MainActor in
            for u in urls { Store.shared.handle(url: u) }
            guard quiet else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            if cold || Date().timeIntervalSince(lastActivation) < 1.5 { NSApp.hide(nil) }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        lastActivation = Date()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NotificationCenter.default.post(name: .dailiesOpenMainWindow, object: nil) }
        return true
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationCenter.default.post(name: .dailiesOpenMainWindow, object: nil)
        NSApp.activate(ignoringOtherApps: true)
        completionHandler()
    }
}
