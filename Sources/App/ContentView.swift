import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case today, stats, library, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .stats: return "Stats"
        case .library: return "Library"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "flame.fill"
        case .stats: return "chart.bar.fill"
        case .library: return "square.grid.2x2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

extension Notification.Name {
    static let dailiesShowSettings = Notification.Name("com.yahya.dailies.showSettings")
}

/// Hand-rolled sidebar + detail (no AppKit-backed List, which mis-renders in this toolchain).
struct ContentView: View {
    @EnvironmentObject var store: Store
    @Local private var selection: SidebarItem = .today

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Spacer().frame(height: 34)
                ForEach(SidebarItem.allCases) { item in
                    SidebarButton(item: item, selected: selection == item) { selection = item }
                }
                Spacer()
                SidebarFooter()
            }
            .padding(12)
            .frame(width: 200)
            .background(Color.white.opacity(0.035))

            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1)

            ZStack {
                Theme.background.ignoresSafeArea()
                switch selection {
                case .today: TodayView()
                case .stats: StatsView()
                case .library: LibraryView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .top) { CelebrationOverlay() }
        .sheet(isPresented: Binding(
            get: { !store.settings.hasOnboarded },
            set: { shown in if !shown { store.updateSettings { $0.hasOnboarded = true } } }
        )) {
            OnboardingView().environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .dailiesShowSettings)) { _ in selection = .settings }
    }
}

struct SidebarButton: View {
    let item: SidebarItem
    let selected: Bool
    let action: () -> Void
    @Local private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? Theme.accent : Theme.text2)
                    .frame(width: 18)
                Text(item.title)
                    .font(.system(size: 13, weight: selected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(selected ? Theme.text : Theme.text2)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.12) : (hover ? Color.white.opacity(0.06) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.12), value: hover)
    }
}

struct SidebarFooter: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let s = store.todayStatus
        HStack(spacing: 8) {
            FlameView(streak: store.currentStreak, size: 18, atRisk: store.streakAtRisk)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(store.currentStreak) day\(store.currentStreak == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                Text("\(s.done)/\(s.goal) today")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.text3)
            }
            Spacer()
        }
        .padding(10)
        .card(radius: 10)
    }
}
