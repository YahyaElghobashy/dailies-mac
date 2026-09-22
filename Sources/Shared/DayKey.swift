import Foundation

/// Local-calendar day keys ("2026-09-21"). Everything streak-related is keyed by these so a
/// day ends at *your* midnight, like Wordle.
enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { formatter.string(from: date) }
    static func today() -> String { key(Date()) }
    static func date(_ key: String) -> Date? { formatter.date(from: key) }

    static func shift(_ key: String, by days: Int) -> String {
        guard let d = date(key),
              let n = Calendar.current.date(byAdding: .day, value: days, to: d) else { return key }
        return self.key(n)
    }

    static func nextMidnight(after date: Date = Date()) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        return cal.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(86_400)
    }

    static func hour(_ date: Date = Date()) -> Int { Calendar.current.component(.hour, from: date) }

    /// Single-letter weekday ("M", "T", ...).
    static func weekdayLetter(_ key: String) -> String {
        guard let d = date(key) else { return "" }
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEEE"
        return f.string(from: d)
    }

    /// "Mon, Sep 21"
    static func pretty(_ key: String) -> String {
        guard let d = date(key) else { return key }
        return d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
