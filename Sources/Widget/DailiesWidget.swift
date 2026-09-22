import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline

struct DailiesEntry: TimelineEntry {
    let date: Date
    let data: AppData
}

struct DailiesProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailiesEntry {
        DebugLog.write("placeholder \(context.family)")
        return DailiesEntry(date: Date(), data: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailiesEntry) -> Void) {
        DebugLog.write("snapshot \(context.family) preview=\(context.isPreview)")
        completion(DailiesEntry(date: Date(), data: context.isPreview ? .sample : Store.snapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailiesEntry>) -> Void) {
        DebugLog.write("timeline \(context.family)")
        let data = Store.snapshot()
        let now = Date()
        var entries = [DailiesEntry(date: now, data: data)]
        let s = data.settings
        // Flip to "streak at risk" copy in the evening without needing a reload.
        if let evening = Calendar.current.date(bySettingHour: s.eveningHour, minute: s.eveningMinute, second: 0, of: now), evening > now {
            entries.append(DailiesEntry(date: evening, data: data))
        }
        // Reset the checklist at local midnight even if the app never runs.
        let midnight = DayKey.nextMidnight(after: now)
        entries.append(DailiesEntry(date: midnight, data: data))
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(1))))
    }
}

// MARK: - View model

struct WidgetModel {
    let data: AppData
    let today: String
    let date: Date

    init(entry: DailiesEntry) {
        data = entry.data
        today = DayKey.key(entry.date)
        date = entry.date
    }

    var status: DayStatus { StreakEngine.status(data, day: today, today: today) }
    var streak: Int { StreakEngine.currentStreak(data, today: today) }
    var must: [Game] { data.games.filter { $0.isEnabled && $0.isMust } }
    var optional: [Game] { data.games.filter { $0.isEnabled && !$0.isMust } }
    var all: [Game] { must + optional }

    func done(_ g: Game) -> Bool { data.days[today]?.done.contains(g.id) ?? false }
    func gameStreak(_ g: Game) -> Int { StreakEngine.gameStreak(data, gameID: g.id, today: today) }

    var atRisk: Bool { !status.complete && streak > 0 && DayKey.hour(date) >= data.settings.eveningHour }
    var face: FaceState { FaceState.compute(status) }

    var headline: String {
        let s = status
        if s.goal == 0 { return "Add games in the app" }
        if face == .crazed { return "CRAZED. All \(s.eligibleCount) done!" }
        if s.complete { return "Perfect day ✓" }
        if atRisk { return "Streak at risk!" }
        if s.done == 0 { return DayKey.hour(date) < 12 ? "Fresh puzzles up" : "Dailies waiting" }
        if s.remaining == 0, s.mustLeft > 0 { return s.mustLeft == 1 ? "1 must-play left" : "\(s.mustLeft) must-plays left" }
        return s.toGo == 1 ? "1 to go" : "\(s.toGo) to go"
    }

    var subline: String {
        let s = status
        var t = "\(s.done)/\(s.goal) games"
        if s.mustTotal > 0 { t += " · ★ \(s.mustDone)/\(s.mustTotal)" }
        return t
    }

    /// Priority order: unfinished must-plays, unfinished rotation, then finished ones.
    func rows(max: Int) -> [Game] {
        let ordered = must.filter { !done($0) } + optional.filter { !done($0) }
                    + must.filter { done($0) } + optional.filter { done($0) }
        return Array(ordered.prefix(max))
    }
}

// MARK: - Widget

struct DailiesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppGroup.widgetKind, provider: DailiesProvider()) { entry in
            DailiesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dailies")
        .description("Your daily puzzles and streak. Tick games off right here, ↗ jumps straight to the game.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct DailiesWidgetBundle: WidgetBundle {
    init() { DebugLog.write("widget bundle init") }
    var body: some Widget {
        DailiesWidget()
    }
}

struct DailiesWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailiesEntry

    var body: some View {
        let m = WidgetModel(entry: entry)
        Group {
            switch family {
            case .systemSmall: SmallView(m: m)
            case .systemMedium: MediumView(m: m)
            case .systemExtraLarge: ExtraLargeView(m: m)
            default: LargeView(m: m)
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(colors: [Color(hex: "#12101C"), Color(hex: "#1C1633")], startPoint: .top, endPoint: .bottom)
                if family == .systemLarge || family == .systemExtraLarge, let art = Art.image("yayas-space") {
                    // Yaya's Space sticker art, ghosted under the large widget.
                    Image(nsImage: art).resizable().scaledToFill().opacity(0.11)
                }
                RadialGradient(colors: [(Theme.flameColors(streak: m.streak).last ?? .orange).opacity(m.streak > 0 ? 0.30 : 0.08), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 240)
            }
        }
    }
}

// MARK: - Pieces

struct StreakBlock: View {
    let m: WidgetModel
    var size: CGFloat = 30

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: m.streak > 0 ? "flame.fill" : "flame")
                .font(.system(size: size * 0.78, weight: .bold))
                .foregroundStyle(Theme.flameGradient(streak: m.streak))
            Text("\(m.streak)")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
    }
}

struct WidgetRing: View {
    let m: WidgetModel
    var size: CGFloat = 40
    var line: CGFloat = 5

    var body: some View {
        let s = m.status
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: line)
            Circle()
                .trim(from: 0, to: max(0.001, s.progress))
                .stroke(s.complete ? AnyShapeStyle(Theme.success)
                                   : AnyShapeStyle(AngularGradient(colors: [Color(hex: "#FFB020"), Color(hex: "#FF3D7F"), Color(hex: "#FFB020")], center: .center)),
                        style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(s.done)/\(s.goal)")
                .font(.system(size: size * 0.26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
    }
}

/// One checklist line: [tick] ★ icon name … streak [↗ open]
struct GameRow: View {
    let m: WidgetModel
    let game: Game
    var compact = false

    var body: some View {
        let done = m.done(game)
        let color = Color(hex: game.color)
        let st = m.gameStreak(game)
        let play = AppGroup.playURL(game.id)
        HStack(spacing: 7) {
            Link(destination: AppGroup.toggleURL(game.id)) {
                ZStack {
                    Circle().fill(done ? Theme.success : Color.white.opacity(0.08))
                    Circle().strokeBorder(done ? Theme.success : (game.isMust ? Theme.gold.opacity(0.8) : Color.white.opacity(0.35)), lineWidth: 1.3)
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Color.black.opacity(0.85))
                    }
                }
                .frame(width: compact ? 17 : 19, height: compact ? 17 : 19)
                .contentShape(Circle())
            }

            Link(destination: play) {
                HStack(spacing: 5) {
                    if game.isMust {
                        Image(systemName: "star.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.gold.opacity(done ? 0.5 : 1))
                    }
                    Image(systemName: game.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(done ? color.opacity(0.5) : color)
                        .frame(width: 13)
                    Text(game.name)
                        .font(.system(size: compact ? 11.5 : 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(done ? Color.white.opacity(0.45) : .white)
                        .strikethrough(done, color: .white.opacity(0.3))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if st > 0 {
                        Text("\(st)🔥")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .contentShape(Rectangle())
            }

            Link(destination: play) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(done ? Color.white.opacity(0.35) : Color.white.opacity(0.75))
                    .frame(width: compact ? 16 : 18, height: compact ? 16 : 18)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
    }
}

struct WeekDots: View {
    let m: WidgetModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let day = DayKey.shift(m.today, by: i - 6)
                let s = StreakEngine.status(m.data, day: day, today: m.today)
                let isToday = day == m.today
                VStack(spacing: 3) {
                    ZStack {
                        Circle().fill(fill(s))
                        if s.frozen {
                            Image(systemName: "snowflake").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.freeze)
                        } else if s.complete {
                            Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(Color.black.opacity(0.8))
                        }
                        if isToday { Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1) }
                    }
                    .frame(width: 18, height: 18)
                    Text(DayKey.weekdayLetter(day))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(isToday ? 0.9 : 0.4))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func fill(_ s: DayStatus) -> Color {
        if s.frozen { return Theme.freeze.opacity(0.3) }
        if s.complete { return Theme.success }
        if s.done > 0 { return Theme.accent.opacity(0.3 + 0.5 * s.progress) }
        return Color.white.opacity(0.08)
    }
}

// MARK: - Families

struct SmallView: View {
    let m: WidgetModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                StreakBlock(m: m, size: 30)
                Spacer()
                MascotView(state: m.face, size: 48)
            }
            Text(m.data.freezes > 0 ? "day streak · ❄️\(m.data.freezes)" : "day streak")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 4)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.headline)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(m.atRisk ? Theme.danger : .white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(m.subline)
                        .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                WidgetRing(m: m, size: 44, line: 5)
            }
        }
        .widgetURL(AppGroup.openURL)
    }
}

struct MediumView: View {
    let m: WidgetModel

    var body: some View {
        let rows = m.rows(max: 5)
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 4) {
                    StreakBlock(m: m, size: 28)
                    Spacer(minLength: 2)
                    MascotView(state: m.face, size: 40)
                }
                Text("day streak").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 4)
                HStack(spacing: 8) {
                    WidgetRing(m: m, size: 40, line: 5)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.headline)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(m.atRisk ? Theme.danger : .white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(m.subline).font(.system(size: 9)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                    }
                }
            }
            .frame(width: 122, alignment: .leading)

            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)

            VStack(spacing: 3) {
                ForEach(rows) { g in GameRow(m: m, game: g, compact: true) }
                if m.all.count > rows.count {
                    Link(destination: AppGroup.openURL) {
                        Text("+\(m.all.count - rows.count) more in Dailies")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Extra-large (macOS 14+): the whole rotation in two columns — widgets can't scroll, so
/// this is the "see everything" size.
struct ExtraLargeView: View {
    let m: WidgetModel

    var body: some View {
        let rows = m.rows(max: 18)
        let split = (rows.count + 1) / 2
        let left = Array(rows.prefix(split))
        let right = Array(rows.dropFirst(split))
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                StreakBlock(m: m, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text("day streak").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                    Text(m.headline)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(m.atRisk ? Theme.danger : .white)
                        .lineLimit(1)
                    Text(m.subline).font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                }
                Spacer()
                WeekDots(m: m).frame(width: 190)
                MascotView(state: m.face, size: 60)
                WidgetRing(m: m, size: 46, line: 5)
            }
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 4) {
                    ForEach(left) { g in GameRow(m: m, game: g) }
                    Spacer(minLength: 0)
                }
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
                VStack(spacing: 4) {
                    ForEach(right) { g in GameRow(m: m, game: g) }
                    if m.all.count > rows.count {
                        Link(destination: AppGroup.openURL) {
                            Text("+\(m.all.count - rows.count) more in Dailies")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct LargeView: View {
    let m: WidgetModel

    var body: some View {
        let rows = m.rows(max: 9)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                StreakBlock(m: m, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text("day streak").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                    Text(m.headline)
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(m.atRisk ? Theme.danger : .white)
                        .lineLimit(1)
                    Text(m.subline).font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                }
                Spacer()
                MascotView(state: m.face, size: 60)
                WidgetRing(m: m, size: 46, line: 5)
            }
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            VStack(spacing: 4) {
                ForEach(rows) { g in GameRow(m: m, game: g) }
                if m.all.count > rows.count {
                    Link(destination: AppGroup.openURL) {
                        Text("+\(m.all.count - rows.count) more in Dailies")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Spacer(minLength: 0)
            WeekDots(m: m)
        }
    }
}
