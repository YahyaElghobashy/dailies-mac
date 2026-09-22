import SwiftUI

// MARK: - Card container

struct CardBackground: ViewModifier {
    var hover: Bool = false
    var tint: Color? = nil
    var radius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(hover ? Theme.cardHover : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(tint?.opacity(0.4) ?? Theme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func card(hover: Bool = false, tint: Color? = nil, radius: CGFloat = 18) -> some View {
        modifier(CardBackground(hover: hover, tint: tint, radius: radius))
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .bold, design: .rounded))
            .foregroundStyle(Color.black.opacity(0.9))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FFC53D"), Color(hex: "#FF7A1A")],
                                                      startPoint: .leading, endPoint: .trailing)))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 8
    var complete: Bool = false

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    complete
                        ? AnyShapeStyle(Theme.success)
                        : AnyShapeStyle(AngularGradient(colors: [Color(hex: "#FFB020"), Color(hex: "#FF3D7F"), Color(hex: "#FFB020")], center: .center)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}

// MARK: - Flame

struct FlameView: View {
    var streak: Int
    var size: CGFloat = 44
    var atRisk: Bool = false

    var body: some View {
        Image(systemName: streak > 0 ? "flame.fill" : "flame")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Theme.flameGradient(streak: streak))
            .shadow(color: (Theme.flameColors(streak: streak).last ?? .orange).opacity(streak > 0 ? 0.55 : 0), radius: size * 0.35)
            .symbolEffect(.bounce, value: streak)
            .symbolEffect(.pulse, isActive: atRisk)
    }
}

// MARK: - Chip

struct Chip: View {
    var text: String
    var systemImage: String? = nil
    var color: Color = Theme.text2

    var body: some View {
        HStack(spacing: 4) {
            if let s = systemImage { Image(systemName: s).font(.system(size: 9, weight: .bold)) }
            Text(text).font(.system(size: 10.5, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .foregroundStyle(color)
        .background(Capsule().fill(color.opacity(0.14)))
        .lineLimit(1)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    var value: String
    var label: String
    var symbol: String
    var color: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.text3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
    }
}

// MARK: - Week strip (last 7 days)

struct WeekStrip: View {
    @EnvironmentObject var store: Store

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { i in
                let day = DayKey.shift(store.today, by: i - 6)
                let s = store.status(for: day)
                let isToday = day == store.today
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(fill(s)).frame(width: 30, height: 30)
                        if s.frozen {
                            Image(systemName: "snowflake").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.freeze)
                        } else if s.complete {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(Color.black.opacity(0.8))
                        } else if s.done > 0 {
                            Text("\(s.done)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                        }
                        if isToday {
                            Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5).frame(width: 30, height: 30)
                        }
                    }
                    Text(DayKey.weekdayLetter(day))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isToday ? Theme.text : Theme.text3)
                }
                .help("\(DayKey.pretty(day)) · \(s.done)/\(s.total)\(s.frozen ? " · frozen" : "")")
            }
        }
    }

    private func fill(_ s: DayStatus) -> Color {
        if s.frozen { return Theme.freeze.opacity(0.25) }
        if s.complete { return Theme.success }
        if s.done > 0 { return Theme.accent.opacity(0.25 + 0.5 * s.progress) }
        return Color.white.opacity(0.07)
    }
}

// MARK: - Heatmap (GitHub-style, Monday at top)

struct HeatmapView: View {
    @EnvironmentObject var store: Store
    var weeks: Int = 16
    var cell: CGFloat = 12

    var body: some View {
        let today = store.today
        let weekday = Calendar.current.component(.weekday, from: DayKey.date(today) ?? Date()) // 1 = Sunday
        let daysFromMonday = (weekday + 5) % 7
        let end = DayKey.shift(today, by: 6 - daysFromMonday) // Sunday of this week
        HStack(alignment: .top, spacing: 3) {
            ForEach(0..<weeks, id: \.self) { w in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { d in
                        let offset = -((weeks - 1 - w) * 7) - (6 - d)
                        let day = DayKey.shift(end, by: offset)
                        let future = day > today
                        let s = store.status(for: day)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(future ? Color.white.opacity(0.02) : color(s))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(day == today ? Color.white.opacity(0.85) : Color.clear, lineWidth: 1)
                            )
                            .frame(width: cell, height: cell)
                            .help(future ? "" : "\(DayKey.pretty(day)) · \(s.done)/\(s.total)\(s.frozen ? " · frozen" : "")")
                    }
                }
            }
        }
    }

    private func color(_ s: DayStatus) -> Color {
        if s.frozen { return Theme.freeze.opacity(0.6) }
        if s.complete { return Theme.success }
        if s.done > 0 { return Theme.accent.opacity(0.25 + 0.6 * s.progress) }
        return Color.white.opacity(0.06)
    }
}

// MARK: - Celebration (toast + confetti)

struct CelebrationOverlay: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ZStack(alignment: .top) {
            if let c = store.celebration, c.big, store.settings.confettiEnabled {
                ConfettiView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            if let c = store.celebration {
                ToastView(celebration: c)
                    .padding(.top, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(c.id)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.celebration?.id)
        .task(id: store.celebration?.id) {
            guard let c = store.celebration else { return }
            try? await Task.sleep(nanoseconds: UInt64((c.big ? 3.4 : 1.8) * 1_000_000_000))
            if store.celebration?.id == c.id { store.celebration = nil }
        }
    }
}

struct ToastView: View {
    var celebration: Celebration

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: celebration.big ? "party.popper.fill" : "checkmark.circle.fill")
                .font(.system(size: celebration.big ? 20 : 16, weight: .bold))
                .foregroundStyle(celebration.big ? Theme.flameGradient(streak: 7)
                                                 : LinearGradient(colors: [Theme.success, Theme.success], startPoint: .top, endPoint: .bottom))
            VStack(alignment: .leading, spacing: 1) {
                Text(celebration.title).font(.system(size: celebration.big ? 15 : 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                Text(celebration.subtitle).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.text2)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Capsule().fill(Color(hex: "#1C1830")).shadow(color: .black.opacity(0.5), radius: 18, y: 8))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
    }
}

struct ConfettiView: View {
    struct Particle {
        let x: Double = .random(in: 0...1)
        let delay: Double = .random(in: 0...0.6)
        let vx: Double = .random(in: -140...140)
        let vy: Double = .random(in: 160...520)
        let size: Double = .random(in: 5...11)
        let hue: Double = .random(in: 0...1)
        let spin: Double = .random(in: -7...7)
        let shape: Int = .random(in: 0...2)
    }

    private let particles: [Particle] = (0..<170).map { _ in Particle() }
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let lt = t - p.delay
                    guard lt > 0, lt < 3.4 else { continue }
                    let x = p.x * size.width + p.vx * lt
                    let y = -20 + p.vy * lt + 0.5 * 240 * lt * lt
                    guard y < size.height + 20 else { continue }
                    let alpha = lt > 2.6 ? max(0, 1 - (lt - 2.6) / 0.8) : 1
                    let h = p.size * (p.shape == 1 ? 0.45 : 1)
                    let rect = CGRect(x: -p.size / 2, y: -h / 2, width: p.size, height: h)
                    var c = context
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(p.spin * lt))
                    let color = Color(hue: p.hue, saturation: 0.85, brightness: 1).opacity(alpha)
                    if p.shape == 2 {
                        c.fill(Path(ellipseIn: rect), with: .color(color))
                    } else {
                        c.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Local view state
//
// The macOS 26+/27 SDKs turn the `@State` *attribute* into a compiler macro backed by a plugin
// that only ships inside Xcode. This machine builds with Command Line Tools only, so `@Local`
// wraps the (macro-free) `State<Value>` struct directly — identical semantics, different spelling.

@propertyWrapper
struct Local<Value>: DynamicProperty {
    private var storage: SwiftUI.State<Value>

    init(wrappedValue: Value) {
        storage = SwiftUI.State(wrappedValue: wrappedValue)
    }

    var wrappedValue: Value {
        get { storage.wrappedValue }
        nonmutating set { storage.wrappedValue = newValue }
    }

    var projectedValue: Binding<Value> { storage.projectedValue }
}
