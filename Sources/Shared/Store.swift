import Foundation
import Combine
import WidgetKit
#if !WIDGET_EXTENSION
import AppKit
import ServiceManagement
#endif

extension Notification.Name {
    static let dailiesStateChanged = Notification.Name("com.yahya.dailies.stateChanged")
    static let dailiesOpenMainWindow = Notification.Name("com.yahya.dailies.openMainWindow")
}

enum AppGroup {
    static let urlScheme = "dailies"
    static let widgetKind = "DailiesWidget"

    /// The real home directory, even from inside the sandboxed widget (where `NSHomeDirectory()`
    /// points at the extension's container instead).
    static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// Shared state lives in ~/Library/Application Support/Dailies. The app (unsandboxed) owns
    /// the folder; the widget extension reaches it through a sandbox file exception in its
    /// entitlements. No App Group needed, so macOS never has to "validate" anything or prompt.
    static var stateDirectory: URL {
        realHome.appendingPathComponent("Library/Application Support/Dailies", isDirectory: true)
    }

    static var stateURL: URL { stateDirectory.appendingPathComponent("state.json") }

    static func playURL(_ gameID: String) -> URL { URL(string: "\(urlScheme)://play/\(gameID)")! }
    /// The widget's tick circles: a link, not an App Intent — App Intents need an Apple Team ID in
    /// the code signature (linkd rejects unsigned bundles), links work for anyone.
    static func toggleURL(_ gameID: String) -> URL {
        let safe = gameID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? gameID
        return URL(string: "\(urlScheme)://toggle/\(safe)") ?? openURL
    }
    static let openURL = URL(string: "\(urlScheme)://open")!
}

/// Tiny append-only trace file. The widget extension runs in chronod's sandbox where the unified
/// log isn't readable from a terminal, so it leaves breadcrumbs next to the state file instead.
enum DebugLog {
    nonisolated static func write(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp) [\(ProcessInfo.processInfo.processName)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let targets = [
            AppGroup.stateDirectory.appendingPathComponent("trace.log"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/dailies-trace.log"),
        ]
        for url in targets {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            if size > 200_000 { try? FileManager.default.removeItem(at: url) }
            if let h = try? FileHandle(forWritingTo: url) {
                _ = try? h.seekToEnd()
                try? h.write(contentsOf: data)
                try? h.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}

struct Celebration: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let big: Bool
}

/// Single source of truth. The app and the widget extension both instantiate it and read/write
/// the same JSON file under ~/Library/Application Support/Dailies; a distributed notification
/// keeps the app's in-memory copy fresh when the widget toggles something.
@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var data: AppData
    @Published private(set) var now = Date()
    @Published var celebration: Celebration? = nil

    private let url: URL
    private var timer: Timer?

    var today: String { DayKey.key(now) }

    private init() {
        url = AppGroup.stateURL
        var d = Store.read(url) ?? AppData()
        Store.mergeCatalog(&d)
        StreakEngine.reconcile(&d, today: DayKey.today())
        data = d
        #if !WIDGET_EXTENSION
        if !FileManager.default.fileExists(atPath: url.path) { persist() }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        #endif
    }

    private func tick() {
        let newNow = Date()
        let dayChanged = DayKey.key(newNow) != DayKey.key(now)
        now = newNow
        if dayChanged {
            refreshFromDisk()
            #if !WIDGET_EXTENSION
            rescheduleNotifications()
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    // MARK: - Disk

    nonisolated static func read(_ url: URL) -> AppData? {
        let bytes: Data
        do { bytes = try Data(contentsOf: url) } catch {
            DebugLog.write("read failed \(url.path): \(error.localizedDescription)")
            return nil
        }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        do { return try dec.decode(AppData.self, from: bytes) } catch {
            DebugLog.write("decode failed: \(error)")
            return nil
        }
    }

    nonisolated static func mergeCatalog(_ d: inout AppData) {
        let known = Set(d.games.map(\.id))
        for g in Catalog.defaults where !known.contains(g.id) {
            var copy = g
            copy.isEnabled = false
            d.games.append(copy)
        }
        for i in d.games.indices where !d.games[i].isCustom {
            if let c = Catalog.game(d.games[i].id) {
                d.games[i].name = c.name
                d.games[i].tagline = c.tagline
                d.games[i].url = c.url
                d.games[i].symbol = c.symbol
                d.games[i].color = c.color
                d.games[i].category = c.category
            }
        }
    }

    /// Fresh, reconciled copy of the state (used by the widget timeline provider).
    nonisolated static func snapshot() -> AppData {
        var d = read(AppGroup.stateURL) ?? AppData()
        mergeCatalog(&d)
        StreakEngine.reconcile(&d, today: DayKey.today())
        let enabledCount = d.games.filter { $0.isEnabled }.count
        DebugLog.write("snapshot ok: \(enabledCount) enabled, \(d.days.count) days")
        return d
    }

    func refreshFromDisk() {
        now = Date()
        var d = Store.read(url) ?? data
        Store.mergeCatalog(&d)
        StreakEngine.reconcile(&d, today: today)
        if d != data { data = d }
    }

    private func persist() {
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            enc.outputFormatting = [.sortedKeys]
            let bytes = try enc.encode(data)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: url, options: .atomic)
        } catch {
            NSLog("Dailies: failed to save state: \(error)")
            DebugLog.write("persist failed: \(error.localizedDescription)")
        }
        WidgetCenter.shared.reloadAllTimelines()
        DistributedNotificationCenter.default().postNotificationName(.dailiesStateChanged, object: nil, userInfo: nil, deliverImmediately: true)
    }

    private func mutate(_ body: (inout AppData) -> Void) {
        var d = data
        body(&d)
        StreakEngine.snapshotToday(&d, today: today)
        StreakEngine.reconcile(&d, today: today)
        data = d
        persist()
    }

    // MARK: - Derived

    var settings: AppSettings { data.settings }
    var games: [Game] { data.games }
    var enabledGames: [Game] { data.games.filter(\.isEnabled) }
    var mustGames: [Game] { enabledGames.filter(\.isMust) }
    var optionalGames: [Game] { enabledGames.filter { !$0.isMust } }
    /// Must-plays first, then the rest — the order the widget and menu bar use.
    var prioritizedGames: [Game] { mustGames + optionalGames }
    var libraryGames: [Game] { data.games.filter { !$0.isEnabled } }
    var dailyGoal: Int { StreakEngine.liveGoal(data) }

    var todayStatus: DayStatus { StreakEngine.status(data, day: today, today: today) }
    var currentStreak: Int { StreakEngine.currentStreak(data, today: today) }
    var bestStreak: Int { StreakEngine.bestStreak(data, today: today) }
    var perfectDays: Int { StreakEngine.perfectDays(data, today: today) }
    var totalCompletions: Int { StreakEngine.totalCompletions(data) }
    var freezes: Int { data.freezes }

    func isDone(_ id: String, day: String? = nil) -> Bool { data.days[day ?? today]?.done.contains(id) ?? false }
    func isOpened(_ id: String) -> Bool { data.days[today]?.opened.contains(id) ?? false }
    func gameStreak(_ id: String) -> Int { StreakEngine.gameStreak(data, gameID: id, today: today) }
    func gameTotal(_ id: String) -> Int { StreakEngine.gameTotal(data, gameID: id) }
    func status(for day: String) -> DayStatus { StreakEngine.status(data, day: day, today: today) }

    var nextGame: Game? {
        mustGames.first { !isDone($0.id) } ?? optionalGames.first { !isDone($0.id) }
    }

    /// The games you'd open right now to finish the day: every unfinished must-play, then enough
    /// optional games to reach the goal.
    var remainingPlan: [Game] {
        let s = todayStatus
        var plan = mustGames.filter { !isDone($0.id) }
        let stillNeeded = max(0, s.remaining - plan.count)
        plan += optionalGames.filter { !isDone($0.id) }.prefix(stillNeeded)
        return plan
    }

    var faceState: FaceState { FaceState.compute(todayStatus) }
    var isEvening: Bool { DayKey.hour(now) >= data.settings.eveningHour }
    var streakAtRisk: Bool { !todayStatus.complete && currentStreak > 0 && isEvening }

    var headline: String {
        let s = todayStatus
        if s.goal == 0 { return "Pick some games in Library" }
        if faceState == .crazed { return "CRAZED MODE. Every single game. Legend." }
        if s.complete { return "Perfect day. Streak locked in." }
        if streakAtRisk { return "Streak at risk — \(s.toGo) to go" }
        if s.done == 0 {
            switch DayKey.hour(now) {
            case ..<12: return "Good morning. Fresh puzzles are up."
            case ..<18: return "Afternoon. Your dailies are waiting."
            default:    return "Evening. Still time to play."
            }
        }
        if s.remaining == 0, s.mustLeft > 0 {
            return s.mustLeft == 1 ? "Goal hit — one must-play left." : "Goal hit — \(s.mustLeft) must-plays left."
        }
        return s.toGo == 1 ? "One more. You've got this." : "\(s.toGo) to go — keep rolling."
    }

    /// Short secondary line for the header: "3 of 5 · 1 must-play left".
    var goalLine: String {
        let s = todayStatus
        var parts = ["\(s.done) of \(s.goal) games"]
        if s.mustTotal > 0 { parts.append(s.mustLeft == 0 ? "must-plays ✓" : "\(s.mustLeft) must-play\(s.mustLeft == 1 ? "" : "s") left") }
        return parts.joined(separator: " · ")
    }

    var shareText: String {
        let s = todayStatus
        var lines: [String] = []
        lines.append("Dailies · \(DayKey.pretty(today)) · 🔥 \(currentStreak)-day streak")
        lines.append(prioritizedGames.map { isDone($0.id) ? ($0.isMust ? "🟨" : "🟩") : "⬜" }.joined())
        var tail = "\(s.done)/\(s.goal) goal"
        if s.mustTotal > 0 { tail += " · must \(s.mustDone)/\(s.mustTotal)" }
        tail += " · best \(bestStreak)"
        lines.append(tail)
        return lines.joined(separator: "\n")
    }

    static let praise = ["Nice.", "Clean.", "Sharp.", "On a roll.", "Brain: fed.", "That's the stuff.",
                         "Unstoppable.", "Keep going.", "Big brain hours.", "Locked in."]

    // MARK: - Mutations

    func toggle(_ id: String) {
        let wasComplete = todayStatus.complete
        let wasFace = faceState
        let wasDone = isDone(id)
        let day = today
        mutate { d in
            var rec = d.days[day] ?? DayRecord()
            if wasDone {
                rec.done.remove(id)
            } else {
                rec.done.insert(id)
                rec.opened.remove(id)
            }
            d.days[day] = rec
            if StreakEngine.isComplete(d, day: day, today: day), d.days[day]?.completedAt == nil {
                d.days[day]?.completedAt = Date()
            }
        }
        #if !WIDGET_EXTENSION
        let nowComplete = todayStatus.complete
        let nowFace = faceState
        if !wasDone {
            if nowFace == .crazed && wasFace != .crazed {
                playSound("Hero")
                celebration = Celebration(title: "CRAZED MODE 🔥🔥🔥", subtitle: "Every game in the rotation. Legend.", big: true)
            } else if nowComplete && !wasComplete {
                playSound("Hero")
                celebration = Celebration(title: "Perfect day!", subtitle: "\(currentStreak)-day streak 🔥 · both lenses lit", big: true)
            } else if nowFace == .half && wasFace == .idle {
                playSound("Pop")
                celebration = Celebration(title: "Left lens lit 🔥", subtitle: "Halfway to the goal", big: false)
            } else {
                playSound("Pop")
                let left = todayStatus.toGo
                let sub = left == 0 ? "Bonus round" : (left == 1 ? "1 to go" : "\(left) to go")
                celebration = Celebration(title: Store.praise.randomElement() ?? "Nice.", subtitle: sub, big: false)
            }
        }
        rescheduleNotifications()
        #endif
    }

    func markOpened(_ id: String) {
        guard !isOpened(id), !isDone(id) else { return }
        let day = today
        mutate { d in
            var rec = d.days[day] ?? DayRecord()
            rec.opened.insert(id)
            d.days[day] = rec
        }
    }

    func setEnabled(_ id: String, _ on: Bool) {
        mutate { d in
            if let i = d.games.firstIndex(where: { $0.id == id }) { d.games[i].isEnabled = on }
        }
        #if !WIDGET_EXTENSION
        rescheduleNotifications()
        #endif
    }

    func setMust(_ id: String, _ on: Bool) {
        mutate { d in
            if let i = d.games.firstIndex(where: { $0.id == id }) { d.games[i].isMust = on }
        }
    }

    func setDailyGoal(_ n: Int) {
        let cap = max(1, enabledGames.count)
        mutate { d in d.settings.dailyGoal = min(max(1, n), cap) }
        #if !WIDGET_EXTENSION
        rescheduleNotifications()
        #endif
    }

    /// Nudge an enabled game up or down one slot in the rotation.
    func moveEnabled(_ id: String, by delta: Int) {
        mutate { d in
            var enabled = d.games.filter(\.isEnabled)
            let disabled = d.games.filter { !$0.isEnabled }
            guard let i = enabled.firstIndex(where: { $0.id == id }) else { return }
            let j = i + delta
            guard j >= 0, j < enabled.count else { return }
            enabled.swapAt(i, j)
            d.games = enabled + disabled
        }
    }

    func moveEnabled(from source: IndexSet, to destination: Int) {
        mutate { d in
            var enabled = d.games.filter(\.isEnabled)
            let disabled = d.games.filter { !$0.isEnabled }
            enabled.move(fromOffsets: source, toOffset: destination)
            d.games = enabled + disabled
        }
    }

    func addCustomGame(name: String, url: URL, symbol: String, color: String, isMust: Bool) {
        let id = "custom-" + UUID().uuidString.prefix(8).lowercased()
        mutate { d in
            let g = Game(id: id, name: name, tagline: url.host ?? "", url: url.absoluteString, symbol: symbol,
                         color: color, category: .custom, isEnabled: true, isMust: isMust, isCustom: true)
            let insertAt = d.games.lastIndex(where: { $0.isEnabled }).map { $0 + 1 } ?? 0
            d.games.insert(g, at: insertAt)
        }
    }

    func removeGame(_ id: String) {
        mutate { d in d.games.removeAll { $0.id == id && $0.isCustom } }
    }

    func updateSettings(_ body: (inout AppSettings) -> Void) {
        mutate { d in body(&d.settings) }
        #if !WIDGET_EXTENSION
        rescheduleNotifications()
        #endif
    }

    func resetToday() {
        let day = today
        mutate { d in d.days[day] = nil }
    }

    func resetAll() {
        mutate { d in
            var fresh = AppData()
            fresh.settings = d.settings
            d = fresh
        }
    }

    // MARK: - App-only behaviour

    #if !WIDGET_EXTENSION
    func play(_ game: Game) {
        markOpened(game.id)
        NSWorkspace.shared.open(game.url)
    }

    func playNext() {
        if let g = nextGame { play(g) }
    }

    func openAllRemaining() {
        for g in remainingPlan { play(g) }
    }

    /// dailies://play/<id>  ·  dailies://toggle/<id>  ·  dailies://open
    func handle(url: URL) {
        guard url.scheme?.lowercased() == AppGroup.urlScheme else { return }
        let host = url.host?.lowercased() ?? ""
        let id = url.pathComponents.filter { $0 != "/" }.first ?? ""
        switch host {
        case "play":
            if let g = games.first(where: { $0.id == id }) { play(g) }
        case "toggle":
            if games.contains(where: { $0.id == id }) { toggle(id) }
        default:
            NotificationCenter.default.post(name: .dailiesOpenMainWindow, object: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func rescheduleNotifications() {
        Notifications.reschedule(store: self)
    }

    private func playSound(_ name: String) {
        guard data.settings.soundEnabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    func copyShareCard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(shareText, forType: .string)
        celebration = Celebration(title: "Copied!", subtitle: "Share card is on your clipboard", big: false)
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            updateSettings { $0.launchAtLogin = on }
        } catch {
            NSLog("Dailies: launch at login failed: \(error)")
            let actual = SMAppService.mainApp.status == .enabled
            updateSettings { $0.launchAtLogin = actual }
        }
    }

    func syncLaunchAtLogin() {
        let enabled = SMAppService.mainApp.status == .enabled
        if enabled != data.settings.launchAtLogin { updateSettings { $0.launchAtLogin = enabled } }
    }
    #endif
}
