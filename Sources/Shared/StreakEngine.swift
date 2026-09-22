import Foundation

/// Where today (or any day) stands against its rules.
struct DayStatus {
    var day: String
    var goal: Int            // games needed for the day to count
    var eligibleCount: Int   // enabled games that day
    var done: Int            // eligible games finished
    var mustTotal: Int
    var mustDone: Int
    var complete: Bool
    var frozen: Bool

    var mustLeft: Int { max(0, mustTotal - mustDone) }
    var remaining: Int { max(0, goal - done) }
    /// Everything still needed, counting must-plays that also count toward the goal only once.
    var toGo: Int { max(remaining, mustLeft) }
    var progress: Double { goal == 0 ? 0 : min(1, Double(done) / Double(goal)) }
    var total: Int { goal }
}

/// The rules that apply on a given day (snapshotted per day so history never shifts under you).
struct DayRules {
    var must: Set<String>
    var eligible: Set<String>
    var goal: Int
}

/// Pure functions over `AppData`. Used identically by the app and the widget so both always
/// agree on what the streak is.
enum StreakEngine {
    static func mustIDs(_ data: AppData) -> [String] {
        data.games.filter { $0.isEnabled && $0.isMust }.map(\.id)
    }

    static func eligibleIDs(_ data: AppData) -> [String] {
        data.games.filter(\.isEnabled).map(\.id)
    }

    /// The numeric goal, clamped to what's actually enabled.
    static func liveGoal(_ data: AppData) -> Int {
        let n = eligibleIDs(data).count
        return n == 0 ? 0 : min(max(1, data.settings.dailyGoal), n)
    }

    static func rules(_ data: AppData, day: String, today: String) -> DayRules {
        if day == today {
            return DayRules(must: Set(mustIDs(data)), eligible: Set(eligibleIDs(data)), goal: liveGoal(data))
        }
        guard let r = data.days[day] else { return DayRules(must: [], eligible: [], goal: 0) }
        if r.eligible.isEmpty {
            // Record from before numeric goals existed: every required game was the rule.
            return DayRules(must: r.required, eligible: r.required, goal: r.required.count)
        }
        return DayRules(must: r.required, eligible: r.eligible, goal: r.goal)
    }

    static func isComplete(_ data: AppData, day: String, today: String) -> Bool {
        guard let r = data.days[day] else { return false }
        if r.frozen { return true }
        let ru = rules(data, day: day, today: today)
        guard ru.goal > 0 else { return false }
        return ru.must.isSubset(of: r.done) && r.done.intersection(ru.eligible).count >= ru.goal
    }

    static func status(_ data: AppData, day: String, today: String) -> DayStatus {
        let ru = rules(data, day: day, today: today)
        let r = data.days[day]
        let done = r?.done.intersection(ru.eligible).count ?? 0
        let mustDone = r?.done.intersection(ru.must).count ?? 0
        let frozen = r?.frozen ?? false
        let complete = frozen || (ru.goal > 0 && mustDone == ru.must.count && done >= ru.goal)
        return DayStatus(day: day, goal: ru.goal, eligibleCount: ru.eligible.count, done: done,
                         mustTotal: ru.must.count, mustDone: mustDone, complete: complete, frozen: frozen)
    }

    /// Consecutive complete days ending today (if done) or yesterday (still alive, at risk).
    static func currentStreak(_ data: AppData, today: String) -> Int {
        var day = isComplete(data, day: today, today: today) ? today : DayKey.shift(today, by: -1)
        var n = 0
        while n < 3650, isComplete(data, day: day, today: today) {
            n += 1
            day = DayKey.shift(day, by: -1)
        }
        return n
    }

    static func bestStreak(_ data: AppData, today: String) -> Int {
        guard let first = data.days.keys.min() else { return 0 }
        var best = 0, run = 0, guardCount = 0
        var day = first
        while day <= today, guardCount < 3650 {
            if isComplete(data, day: day, today: today) { run += 1; best = max(best, run) } else { run = 0 }
            day = DayKey.shift(day, by: 1)
            guardCount += 1
        }
        return max(best, currentStreak(data, today: today))
    }

    static func gameStreak(_ data: AppData, gameID: String, today: String) -> Int {
        let doneToday = data.days[today]?.done.contains(gameID) ?? false
        var day = doneToday ? today : DayKey.shift(today, by: -1)
        var n = 0
        while n < 3650, data.days[day]?.done.contains(gameID) ?? false {
            n += 1
            day = DayKey.shift(day, by: -1)
        }
        return n
    }

    static func gameTotal(_ data: AppData, gameID: String) -> Int {
        data.days.values.filter { $0.done.contains(gameID) }.count
    }

    static func perfectDays(_ data: AppData, today: String) -> Int {
        data.days.keys.filter { isComplete(data, day: $0, today: today) && !(data.days[$0]?.frozen ?? false) }.count
    }

    static func totalCompletions(_ data: AppData) -> Int {
        data.days.values.reduce(0) { $0 + $1.done.count }
    }

    static func daysPlayed(_ data: AppData) -> Int {
        data.days.values.filter { !$0.done.isEmpty }.count
    }

    /// Writes today's rules onto today's record so they survive later settings changes.
    static func snapshotToday(_ data: inout AppData, today: String) {
        var rec = data.days[today] ?? DayRecord()
        rec.required = Set(mustIDs(data))
        rec.eligible = Set(eligibleIDs(data))
        rec.goal = liveGoal(data)
        data.days[today] = rec
    }

    /// Spend streak freezes on missed days and award new ones every 7-day milestone.
    /// Idempotent — safe to call from the app and the widget on every load.
    static func reconcile(_ data: inout AppData, today: String) {
        let yesterday = DayKey.shift(today, by: -1)
        var day: String
        if let last = data.lastReconciledDay {
            day = DayKey.shift(last, by: 1)
        } else {
            day = data.days.keys.min() ?? yesterday
        }
        var loops = 0
        while day <= yesterday, loops < 400 {
            if !isComplete(data, day: day, today: today) {
                let prev = DayKey.shift(day, by: -1)
                let streakWasAlive = isComplete(data, day: prev, today: today)
                if streakWasAlive, data.freezes > 0 {
                    var rec = data.days[day] ?? DayRecord()
                    rec.frozen = true
                    if rec.eligible.isEmpty {
                        rec.required = Set(mustIDs(data))
                        rec.eligible = Set(eligibleIDs(data))
                        rec.goal = liveGoal(data)
                    }
                    data.days[day] = rec
                    data.freezes -= 1
                }
            }
            day = DayKey.shift(day, by: 1)
            loops += 1
        }
        data.lastReconciledDay = yesterday

        let streak = currentStreak(data, today: today)
        let endDay = isComplete(data, day: today, today: today) ? today : yesterday
        if streak > 0, streak % 7 == 0, data.freezeAwardedForDay != endDay {
            data.freezes = min(2, data.freezes + 1)
            data.freezeAwardedForDay = endDay
        }
    }
}

// MARK: - Badges

struct Badge: Identifiable, Hashable {
    enum Kind { case streak, perfectDays, completions }
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let threshold: Int
    let kind: Kind

    static let all: [Badge] = [
        Badge(id: "spark",      title: "Spark",         detail: "3-day streak",       symbol: "flame",               threshold: 3,   kind: .streak),
        Badge(id: "week",       title: "Week Warrior",  detail: "7-day streak",       symbol: "7.circle.fill",       threshold: 7,   kind: .streak),
        Badge(id: "fortnight",  title: "Fortnight",     detail: "14-day streak",      symbol: "14.circle.fill",      threshold: 14,  kind: .streak),
        Badge(id: "month",      title: "Monthly Mind",  detail: "30-day streak",      symbol: "30.circle.fill",      threshold: 30,  kind: .streak),
        Badge(id: "fifty",      title: "Half Century",  detail: "50-day streak",      symbol: "50.circle.fill",      threshold: 50,  kind: .streak),
        Badge(id: "century",    title: "Centurion",     detail: "100-day streak",     symbol: "medal.fill",          threshold: 100, kind: .streak),
        Badge(id: "year",       title: "Year One",      detail: "365-day streak",     symbol: "crown.fill",          threshold: 365, kind: .streak),
        Badge(id: "first",      title: "First Blood",   detail: "First puzzle done",  symbol: "checkmark.seal.fill", threshold: 1,   kind: .completions),
        Badge(id: "hundred",    title: "100 Club",      detail: "100 puzzles solved", symbol: "100.square.fill",     threshold: 100, kind: .completions),
        Badge(id: "grinder",    title: "Grinder",       detail: "500 puzzles solved", symbol: "bolt.fill",           threshold: 500, kind: .completions),
        Badge(id: "perfect10",  title: "Perfect 10",    detail: "10 perfect days",    symbol: "star.fill",           threshold: 10,  kind: .perfectDays),
        Badge(id: "perfect50",  title: "Perfectionist", detail: "50 perfect days",    symbol: "sparkles",            threshold: 50,  kind: .perfectDays),
    ]

    func earned(in data: AppData, today: String) -> Bool {
        switch kind {
        case .streak:      return StreakEngine.bestStreak(data, today: today) >= threshold
        case .perfectDays: return StreakEngine.perfectDays(data, today: today) >= threshold
        case .completions: return StreakEngine.totalCompletions(data) >= threshold
        }
    }
}
