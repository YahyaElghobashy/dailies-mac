import SwiftUI

struct GameCard: View {
    @EnvironmentObject var store: Store
    let game: Game
    @Local private var hover = false

    var body: some View {
        let done = store.isDone(game.id)
        let opened = store.isOpened(game.id)
        let streak = store.gameStreak(game.id)
        let color = Color(hex: game.color)

        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.gameGradient(game.color))
                    .opacity(done ? 1 : 0.85)
                Image(systemName: game.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)
            .shadow(color: color.opacity(hover || done ? 0.45 : 0.15), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(game.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if game.isMust { Chip(text: "must", systemImage: "star.fill", color: Theme.gold) }
                }
                Text(statusLine(done: done, opened: opened))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(done ? Theme.success : (opened ? Theme.accent : Theme.text3))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Chip(text: game.category.label, systemImage: game.category.symbol, color: color)
                    if streak > 0 {
                        Chip(text: "\(streak)", systemImage: "flame.fill", color: streak >= 7 ? Color(hex: "#FF3D7F") : Theme.accent)
                    }
                    Text(game.host).font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.text3).lineLimit(1)
                }
            }
            Spacer(minLength: 6)

            CheckButton(done: done, color: color) { store.toggle(game.id) }
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .card(hover: hover, tint: done ? Theme.success : (hover ? color : nil))
        .scaleEffect(hover ? 1.015 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hover)
        .onHover { hover = $0 }
        .onTapGesture { store.play(game) }
        .contextMenu {
            Button(done ? "Mark not done" : "Mark done") { store.toggle(game.id) }
            Button("Open \(game.name)") { store.play(game) }
            Button("Copy link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(game.url.absoluteString, forType: .string)
            }
            Divider()
            Button(game.isMust ? "Not a must-play" : "Make must-play") { store.setMust(game.id, !game.isMust) }
            Button("Remove from today's list") { store.setEnabled(game.id, false) }
        }
        .help("Click to play · \(game.url.absoluteString)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.name), \(done ? "done" : "not done")")
    }

    private func statusLine(done: Bool, opened: Bool) -> String {
        if done { return "Done ✓ — see you tomorrow" }
        if opened { return "Opened — mark done when you finish" }
        return game.tagline
    }
}

struct CheckButton: View {
    var done: Bool
    var color: Color
    var action: () -> Void
    @Local private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(done ? Theme.success : Color.white.opacity(hover ? 0.12 : 0.06))
                Circle().strokeBorder(done ? Theme.success : Color.white.opacity(hover ? 0.55 : 0.25), lineWidth: 1.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(done ? Color.black.opacity(0.85) : Color.white.opacity(hover ? 0.7 : 0.0))
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .scaleEffect(hover ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .symbolEffect(.bounce, value: done)
        .onHover { hover = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: done)
        .animation(.easeOut(duration: 0.15), value: hover)
        .help(done ? "Mark as not done" : "Mark as done")
    }
}
