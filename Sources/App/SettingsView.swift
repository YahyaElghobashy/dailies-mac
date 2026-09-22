import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @StateObject private var perms = PermissionsMonitor()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
                GoalCard()
                RemindersCard(perms: perms)
                WidgetCard(perms: perms)
                AppCard(perms: perms)
                DangerCard()
                Text("Checks refresh every 2 s while this screen is open · last \(perms.lastChecked.formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 10.5)).foregroundStyle(Theme.text3)
            }
            .padding(24)
            .padding(.top, 6)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .onAppear { perms.start() }
        .onDisappear { perms.stop() }
    }
}

// MARK: - Building blocks

struct SettingsCard<Content: View>: View {
    var title: String
    var symbol: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.accent)
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
            }
            if let s = subtitle {
                Text(s).font(.system(size: 11.5)).foregroundStyle(Theme.text3).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct StatusRow<Trailing: View>: View {
    var title: String
    var detail: String
    var level: PermissionsMonitor.Level
    @ViewBuilder var trailing: () -> Trailing

    private var color: Color {
        switch level {
        case .ok: return Theme.success
        case .warn: return Theme.gold
        case .off: return Theme.danger
        case .unknown: return Theme.text3
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 9, height: 9).shadow(color: color.opacity(0.8), radius: 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                Text(detail).font(.system(size: 11)).foregroundStyle(Theme.text3)
                    .contentTransition(.opacity)
            }
            Spacer()
            trailing()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(color.opacity(0.25)))
        .animation(.easeOut(duration: 0.2), value: detail)
    }
}

struct LabeledToggle: View {
    var title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text)
                if let s = subtitle { Text(s).font(.system(size: 11)).foregroundStyle(Theme.text3) }
            }
            Spacer()
            Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden().tint(Theme.accent)
        }
    }
}

// MARK: - Cards

struct GoalCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let s = store.todayStatus
        let enabled = store.enabledGames
        SettingsCard(title: "Daily goal", symbol: "target",
                     subtitle: "A day counts (and the streak grows) when you finish the goal — plus every must-play. Must-plays show first in the widget.") {
            HStack(spacing: 12) {
                Stepper(value: Binding(get: { store.dailyGoal }, set: { store.setDailyGoal($0) }),
                        in: 1...max(1, enabled.count)) {
                    HStack(spacing: 4) {
                        Text("Finish").foregroundStyle(Theme.text2)
                        Text("\(store.dailyGoal)").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                        Text("of \(enabled.count) games a day").foregroundStyle(Theme.text2)
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                }
                .disabled(enabled.isEmpty)
                Spacer()
                Chip(text: s.complete ? "Today complete ✓" : "Today \(s.done)/\(s.goal)",
                     systemImage: s.complete ? "checkmark.seal.fill" : "circle.dashed",
                     color: s.complete ? Theme.success : Theme.accent)
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack(spacing: 6) {
                Image(systemName: "star.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.gold)
                Text("Must-play every day").font(.system(size: 12.5, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                Text("· \(store.mustGames.count) starred").font(.system(size: 11)).foregroundStyle(Theme.text3)
            }
            if enabled.isEmpty {
                Text("Enable some games in Library first.").font(.system(size: 11.5)).foregroundStyle(Theme.text3)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    ForEach(enabled) { g in MustChip(game: g) }
                }
            }
        }
    }
}

struct MustChip: View {
    @EnvironmentObject var store: Store
    let game: Game
    @Local private var hover = false

    var body: some View {
        Button { store.setMust(game.id, !game.isMust) } label: {
            HStack(spacing: 7) {
                Image(systemName: game.isMust ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(game.isMust ? Theme.gold : Theme.text3)
                Image(systemName: game.symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: game.color))
                Text(game.name).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(game.isMust ? Theme.text : Theme.text2).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(game.isMust ? Theme.gold.opacity(0.16) : Color.white.opacity(hover ? 0.08 : 0.045)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(game.isMust ? Theme.gold.opacity(0.5) : Theme.stroke))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: game.isMust)
    }
}

struct RemindersCard: View {
    @EnvironmentObject var store: Store
    @ObservedObject var perms: PermissionsMonitor

    var body: some View {
        SettingsCard(title: "Reminders", symbol: "bell.badge.fill",
                     subtitle: "A morning nudge and an evening “streak at risk” alert. Nothing fires once the day is complete.") {
            StatusRow(title: "Notification permission", detail: perms.notifText, level: perms.notifLevel) {
                switch perms.notifStatus {
                case .notDetermined:
                    Button("Allow notifications") { perms.requestNotifications() }.buttonStyle(PrimaryButtonStyle())
                case .denied:
                    Button("Open System Settings") { perms.openNotificationSettings() }.buttonStyle(SecondaryButtonStyle())
                default:
                    Button("Send a test") { perms.sendTestNotification() }.buttonStyle(SecondaryButtonStyle())
                }
            }
            LabeledToggle(title: "Daily reminders", isOn: bind(\.remindersEnabled))
            timeRow("Morning nudge", hour: \.morningHour, minute: \.morningMinute)
                .disabled(!store.settings.remindersEnabled)
            LabeledToggle(title: "Evening “streak at risk” alert", isOn: bind(\.eveningEnabled))
                .disabled(!store.settings.remindersEnabled)
            timeRow("Evening alert", hour: \.eveningHour, minute: \.eveningMinute)
                .disabled(!store.settings.remindersEnabled || !store.settings.eveningEnabled)
        }
    }

    private func timeRow(_ title: String, hour: WritableKeyPath<AppSettings, Int>, minute: WritableKeyPath<AppSettings, Int>) -> some View {
        HStack {
            Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.text)
            Spacer()
            DatePicker("", selection: timeBinding(hour: hour, minute: minute), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.stepperField)
        }
    }

    private func bind(_ kp: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { store.settings[keyPath: kp] },
                set: { v in store.updateSettings { $0[keyPath: kp] = v } })
    }

    private func timeBinding(hour: WritableKeyPath<AppSettings, Int>, minute: WritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(get: {
            let s = store.settings
            return Calendar.current.date(bySettingHour: s[keyPath: hour], minute: s[keyPath: minute], second: 0, of: Date()) ?? Date()
        }, set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            store.updateSettings {
                $0[keyPath: hour] = c.hour ?? 9
                $0[keyPath: minute] = c.minute ?? 0
            }
        })
    }
}

struct WidgetCard: View {
    @ObservedObject var perms: PermissionsMonitor

    var body: some View {
        SettingsCard(title: "Desktop widget", symbol: "rectangle.3.group.fill",
                     subtitle: "Small, Medium and Large. Tick circles are live buttons; the name and ↗ jump straight to the game. Must-plays come first, unfinished games stay above finished ones.") {
            StatusRow(title: "Widget on desktop", detail: perms.widgetText, level: perms.widgetLevel) {
                Button("Refresh widgets") { perms.reloadWidgets() }.buttonStyle(SecondaryButtonStyle())
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "hand.point.up.left.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.text3)
                Text("To add it: right-click the desktop → **Edit Widgets** → search **Dailies** → drag a size onto the desktop or into Notification Center. This row turns green the moment it's placed.")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AppCard: View {
    @EnvironmentObject var store: Store
    @ObservedObject var perms: PermissionsMonitor

    var body: some View {
        SettingsCard(title: "App", symbol: "macwindow") {
            StatusRow(title: "Launch at login",
                      detail: perms.launchAtLogin ? "On — the menu-bar flame and reminders stay alive after a restart" : "Off — reminders need the app running",
                      level: perms.launchAtLogin ? .ok : .warn) {
                Toggle("", isOn: Binding(get: { perms.launchAtLogin }, set: { on in
                    store.setLaunchAtLogin(on)
                    Task { await perms.refresh() }
                }))
                .toggleStyle(.switch).labelsHidden().tint(Theme.accent)
            }
            LabeledToggle(title: "Sounds", subtitle: "A soft pop per game, a fanfare on a perfect day", isOn: bind(\.soundEnabled))
            LabeledToggle(title: "Confetti on a perfect day", isOn: bind(\.confettiEnabled))
        }
    }

    private func bind(_ kp: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(get: { store.settings[keyPath: kp] },
                set: { v in store.updateSettings { $0[keyPath: kp] = v } })
    }
}

struct DangerCard: View {
    @EnvironmentObject var store: Store
    @Local private var confirmReset = false

    var body: some View {
        SettingsCard(title: "Danger zone", symbol: "exclamationmark.triangle.fill") {
            HStack(spacing: 10) {
                Button("Reset today's checks") { store.resetToday() }.buttonStyle(SecondaryButtonStyle())
                Button("Erase all history…") { confirmReset = true }.buttonStyle(SecondaryButtonStyle())
                    .confirmationDialog("Erase all streaks and history?", isPresented: $confirmReset, titleVisibility: .visible) {
                        Button("Erase everything", role: .destructive) { store.resetAll() }
                    } message: {
                        Text("Your game list and settings stay. This can't be undone.")
                    }
            }
        }
    }
}
