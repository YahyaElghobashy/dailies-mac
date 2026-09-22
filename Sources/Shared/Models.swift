import Foundation

// MARK: - Category

enum GameCategory: String, Codable, CaseIterable, Identifiable {
    case deduction, word, geography, logic, trivia, screen, linkedin, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deduction: return "Deduction"
        case .word:      return "Word"
        case .geography: return "Geography"
        case .logic:     return "Logic"
        case .trivia:    return "Trivia"
        case .screen:    return "Film & Music"
        case .linkedin:  return "LinkedIn"
        case .custom:    return "Custom"
        }
    }

    var symbol: String {
        switch self {
        case .deduction: return "magnifyingglass"
        case .word:      return "textformat.abc"
        case .geography: return "globe.americas.fill"
        case .logic:     return "brain.head.profile"
        case .trivia:    return "questionmark.circle.fill"
        case .screen:    return "film.fill"
        case .linkedin:  return "briefcase.fill"
        case .custom:    return "star.fill"
        }
    }
}

// MARK: - Game

struct Game: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var tagline: String
    var url: URL
    var symbol: String
    var color: String
    var category: GameCategory
    var isEnabled: Bool
    /// Must-play: required every day regardless of the numeric goal. Shown first in the widget.
    var isMust: Bool
    var isCustom: Bool

    init(id: String, name: String, tagline: String, url: String, symbol: String, color: String,
         category: GameCategory, isEnabled: Bool = false, isMust: Bool = false, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.url = URL(string: url) ?? URL(string: "https://example.com")!
        self.symbol = symbol
        self.color = color
        self.category = category
        self.isEnabled = isEnabled
        self.isMust = isMust
        self.isCustom = isCustom
    }

    enum CodingKeys: String, CodingKey {
        case id, name, tagline, url, symbol, color, category, isEnabled, isMust, isCustom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        tagline = (try? c.decode(String.self, forKey: .tagline)) ?? ""
        url = try c.decode(URL.self, forKey: .url)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? "star.fill"
        color = (try? c.decode(String.self, forKey: .color)) ?? "#F97316"
        category = (try? c.decode(GameCategory.self, forKey: .category)) ?? .custom
        isEnabled = (try? c.decode(Bool.self, forKey: .isEnabled)) ?? true
        isMust = (try? c.decode(Bool.self, forKey: .isMust)) ?? false
        isCustom = (try? c.decode(Bool.self, forKey: .isCustom)) ?? false
    }

    var host: String {
        let h = url.host ?? ""
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }
}

// MARK: - Day record

struct DayRecord: Codable, Equatable {
    var done: Set<String> = []
    var opened: Set<String> = []
    /// Snapshot of the rules that applied on this day (must-plays, enabled games, numeric goal),
    /// so later Library/Settings changes never retroactively break old streaks.
    var required: Set<String> = []          // must-play ids
    var eligible: Set<String> = []          // enabled ids
    var goal: Int = 0                       // games needed
    var frozen: Bool = false
    var completedAt: Date? = nil

    init() {}

    enum CodingKeys: String, CodingKey { case done, opened, required, eligible, goal, frozen, completedAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        done = (try? c.decode(Set<String>.self, forKey: .done)) ?? []
        opened = (try? c.decode(Set<String>.self, forKey: .opened)) ?? []
        required = (try? c.decode(Set<String>.self, forKey: .required)) ?? []
        eligible = (try? c.decode(Set<String>.self, forKey: .eligible)) ?? []
        goal = (try? c.decode(Int.self, forKey: .goal)) ?? 0
        frozen = (try? c.decode(Bool.self, forKey: .frozen)) ?? false
        completedAt = try? c.decode(Date.self, forKey: .completedAt)
    }
}

// MARK: - Settings

struct AppSettings: Codable, Equatable {
    /// Minimum number of enabled games to finish for the day to count (must-plays always required).
    var dailyGoal: Int = 5
    var remindersEnabled: Bool = true
    var morningHour: Int = 9
    var morningMinute: Int = 0
    var eveningEnabled: Bool = true
    var eveningHour: Int = 20
    var eveningMinute: Int = 0
    var soundEnabled: Bool = true
    var confettiEnabled: Bool = true
    var launchAtLogin: Bool = false
    var hasOnboarded: Bool = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case dailyGoal, remindersEnabled, morningHour, morningMinute, eveningEnabled, eveningHour, eveningMinute
        case soundEnabled, confettiEnabled, launchAtLogin, hasOnboarded
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyGoal = (try? c.decode(Int.self, forKey: .dailyGoal)) ?? 5
        remindersEnabled = (try? c.decode(Bool.self, forKey: .remindersEnabled)) ?? true
        morningHour = (try? c.decode(Int.self, forKey: .morningHour)) ?? 9
        morningMinute = (try? c.decode(Int.self, forKey: .morningMinute)) ?? 0
        eveningEnabled = (try? c.decode(Bool.self, forKey: .eveningEnabled)) ?? true
        eveningHour = (try? c.decode(Int.self, forKey: .eveningHour)) ?? 20
        eveningMinute = (try? c.decode(Int.self, forKey: .eveningMinute)) ?? 0
        soundEnabled = (try? c.decode(Bool.self, forKey: .soundEnabled)) ?? true
        confettiEnabled = (try? c.decode(Bool.self, forKey: .confettiEnabled)) ?? true
        launchAtLogin = (try? c.decode(Bool.self, forKey: .launchAtLogin)) ?? false
        hasOnboarded = (try? c.decode(Bool.self, forKey: .hasOnboarded)) ?? false
    }
}

// MARK: - Root state

struct AppData: Codable, Equatable {
    var version: Int = 1
    var games: [Game] = Catalog.defaults
    var days: [String: DayRecord] = [:]
    var freezes: Int = 0
    var freezeAwardedForDay: String? = nil
    var lastReconciledDay: String? = nil
    var settings: AppSettings = AppSettings()
    var createdDay: String = DayKey.today()

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, games, days, freezes, freezeAwardedForDay, lastReconciledDay, settings, createdDay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        games = (try? c.decode([Game].self, forKey: .games)) ?? Catalog.defaults
        days = (try? c.decode([String: DayRecord].self, forKey: .days)) ?? [:]
        freezes = (try? c.decode(Int.self, forKey: .freezes)) ?? 0
        freezeAwardedForDay = try? c.decode(String.self, forKey: .freezeAwardedForDay)
        lastReconciledDay = try? c.decode(String.self, forKey: .lastReconciledDay)
        settings = (try? c.decode(AppSettings.self, forKey: .settings)) ?? AppSettings()
        createdDay = (try? c.decode(String.self, forKey: .createdDay)) ?? DayKey.today()
    }

    /// Demo state used by widget placeholders / gallery previews.
    static var sample: AppData {
        var d = AppData()
        let today = DayKey.today()
        for i in d.games.indices where ["murdle", "wordle"].contains(d.games[i].id) { d.games[i].isMust = true }
        let must = Set(StreakEngine.mustIDs(d))
        let eligible = Set(StreakEngine.eligibleIDs(d))
        var rec = DayRecord()
        rec.required = must; rec.eligible = eligible; rec.goal = 5
        rec.done = ["wordle", "globle", "li-queens"]
        d.days[today] = rec
        for i in 1...11 {
            var r = DayRecord()
            r.required = must; r.eligible = eligible; r.goal = 5
            r.done = must.union(["globle", "deduce", "li-tango"])
            d.days[DayKey.shift(today, by: -i)] = r
        }
        d.freezes = 1
        return d
    }
}
