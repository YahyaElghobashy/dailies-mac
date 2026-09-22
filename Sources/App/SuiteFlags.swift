import AppKit
import ServiceManagement
import UserNotifications

/// Launch arguments used by the Yaya Suite installer.
///   --permissions-json      print permission state as JSON and exit (no window, no Dock icon)
///   --login-item on|off     register / unregister the login item, then continue
///   --onboarding            show the welcome tour again; a marker file is written when it is done
enum SuiteFlags {
    static let handoffDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/YayaSuite/handoff", isDirectory: true)
    private(set) static var suiteOnboarding = false

    /// From applicationWillFinishLaunching, so the probe never reaches the Dock.
    static func early() {
        guard CommandLine.arguments.contains("--permissions-json") else { return }
        NSApp.setActivationPolicy(.prohibited)
        let sem = DispatchSemaphore(value: 0)
        var notif = "undetermined"
        UNUserNotificationCenter.current().getNotificationSettings { s in
            switch s.authorizationStatus {
            case .authorized, .provisional: notif = "granted"
            case .denied: notif = "denied"
            default: notif = "undetermined"
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 3)
        let json: [String: Any] = ["app": "Dailies", "notifications": notif, "loginItem": SMAppService.mainApp.status == .enabled]
        if let d = try? JSONSerialization.data(withJSONObject: json), let s = String(data: d, encoding: .utf8) { print(s) }
        fflush(stdout)
        exit(0)
    }

    @MainActor static func handle() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--login-item"), i + 1 < args.count {
            let on = args[i + 1].lowercased() == "on"
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch { NSLog("Dailies: login item: \(error)") }
        }
        if args.contains("--onboarding") {
            suiteOnboarding = true
            Store.shared.updateSettings { $0.hasOnboarded = false }
        }
    }

    static func markOnboardingDone() {
        guard suiteOnboarding else { return }
        try? FileManager.default.createDirectory(at: handoffDirectory, withIntermediateDirectories: true)
        try? Data("done \(Date())\n".utf8).write(to: handoffDirectory.appendingPathComponent("dailies.done"))
    }
}
