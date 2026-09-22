import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject private var store = Store.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: store.todayStatus.complete ? "flame.fill" : "flame")
            Text("\(store.currentStreak)")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dailiesOpenMainWindow)) { _ in
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let s = store.todayStatus
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                FlameView(streak: store.currentStreak, size: 22, atRisk: store.streakAtRisk)
                MascotView(state: store.faceState, size: 34, animated: true)
                    .help(store.faceState.caption)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(store.currentStreak)-day streak")
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                    Text(store.goalLine).font(.system(size: 11)).foregroundStyle(Theme.text3).lineLimit(1)
                }
                Spacer()
                ZStack {
                    ProgressRing(progress: s.progress, lineWidth: 4, complete: s.complete)
                    Text("\(s.done)/\(s.total)").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                }
                .frame(width: 34, height: 34)
            }

            Divider().overlay(Color.white.opacity(0.1))

            VStack(spacing: 2) {
                ForEach(store.prioritizedGames) { g in
                    MenuBarRow(game: g)
                }
            }

            Divider().overlay(Color.white.opacity(0.1))

            HStack {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: { Label("Open Dailies", systemImage: "macwindow") }
                .buttonStyle(SecondaryButtonStyle())
                Button { store.copyShareCard() } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(SecondaryButtonStyle()).help("Copy share card")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain).foregroundStyle(Theme.text3).font(.system(size: 11))
            }
        }
        .padding(14)
        .frame(width: 330)
        .background(Theme.background)
    }
}

struct MenuBarRow: View {
    @EnvironmentObject var store: Store
    let game: Game
    @Local private var hover = false

    var body: some View {
        let done = store.isDone(game.id)
        let st = store.gameStreak(game.id)
        HStack(spacing: 8) {
            CheckButton(done: done, color: Color(hex: game.color)) { store.toggle(game.id) }
                .scaleEffect(0.72)
                .frame(width: 24, height: 24)
            Button { store.play(game) } label: {
                HStack(spacing: 6) {
                    Image(systemName: game.symbol).font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: game.color)).frame(width: 14)
                    Text(game.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .strikethrough(done, color: Theme.text3)
                        .foregroundStyle(done ? Theme.text3 : Theme.text)
                    if game.isMust { Image(systemName: "star.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.gold) }
                    Spacer()
                    if st > 0 { Text("🔥\(st)").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Theme.text3) }
                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.text3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(hover ? 0.07 : 0)))
        .onHover { hover = $0 }
    }
}
