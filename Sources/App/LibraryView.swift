import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var store: Store
    @Local private var showAdd = false
    @Local private var search = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Library").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
                        Text("Switch games in and out of your daily rotation, star the ones that are a must, and order them. The goal itself lives in Settings.")
                            .font(.system(size: 11.5)).foregroundStyle(Theme.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button { showAdd = true } label: { Label("Add custom game", systemImage: "plus") }
                        .buttonStyle(PrimaryButtonStyle())
                }

                SearchField(text: $search, prompt: "Search games")

                let enabled = store.enabledGames
                sectionHeader("In today's rotation", count: enabled.count, hint: "★ = must-play · ▲▼ = order")
                if enabled.isEmpty {
                    emptyCard("Nothing in rotation. Flip some games on below.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(enabled.enumerated()), id: \.element.id) { i, g in
                            LibraryRow(game: g, index: i, count: enabled.count)
                        }
                    }
                }

                let more = filteredLibrary
                sectionHeader("More daily games", count: more.count, hint: nil)
                if more.isEmpty {
                    emptyCard(search.isEmpty ? "Everything's in rotation." : "No matches for “\(search)”.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(more) { g in LibraryRow(game: g, index: nil, count: 0) }
                    }
                }
            }
            .padding(24)
            .padding(.top, 6)
        }
        .sheet(isPresented: $showAdd) { AddGameSheet().environmentObject(store) }
    }

    private var filteredLibrary: [Game] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return store.libraryGames.filter {
            q.isEmpty || $0.name.lowercased().contains(q) || $0.category.label.lowercased().contains(q) || $0.tagline.lowercased().contains(q)
        }
    }

    private func sectionHeader(_ t: String, count: Int, hint: String?) -> some View {
        HStack(spacing: 8) {
            Text(t).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
            Text("\(count)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Theme.text3)
                .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(Color.white.opacity(0.08)))
            if let h = hint { Text(h).font(.system(size: 11)).foregroundStyle(Theme.text3) }
            Spacer()
        }
        .padding(.top, 6)
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(Theme.text3)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).card()
    }
}

struct SearchField: View {
    @Binding var text: String
    var prompt: String = "Search"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text3)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(Theme.text3)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.stroke))
        .frame(maxWidth: 380)
    }
}

struct LibraryRow: View {
    @EnvironmentObject var store: Store
    let game: Game
    let index: Int?
    let count: Int
    @Local private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.gameGradient(game.color))
                Image(systemName: game.symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .opacity(game.isEnabled ? 1 : 0.7)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(game.name).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                    Chip(text: game.category.label, color: Color(hex: game.color))
                    if game.isEnabled && game.isMust { Chip(text: "must", systemImage: "star.fill", color: Theme.gold) }
                }
                Text(game.tagline.isEmpty ? game.host : "\(game.tagline) · \(game.host)")
                    .font(.system(size: 11)).foregroundStyle(Theme.text3).lineLimit(1)
            }
            Spacer(minLength: 8)

            if game.isEnabled {
                Button { store.setMust(game.id, !game.isMust) } label: {
                    Image(systemName: game.isMust ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(game.isMust ? Theme.gold : Theme.text3)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(game.isMust ? Theme.gold.opacity(0.15) : Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help(game.isMust ? "Must-play every day (click to make optional)" : "Make this a must-play")

                if let i = index {
                    VStack(spacing: 2) {
                        Button { store.moveEnabled(game.id, by: -1) } label: { Image(systemName: "chevron.up") }
                            .disabled(i == 0)
                        Button { store.moveEnabled(game.id, by: 1) } label: { Image(systemName: "chevron.down") }
                            .disabled(i >= count - 1)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Theme.text3)
                    .opacity(hover ? 1 : 0.35)
                }
            }

            Button { store.play(game) } label: {
                Image(systemName: "arrow.up.right.square").font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.text3).help("Open in browser")

            Toggle("", isOn: Binding(get: { game.isEnabled }, set: { store.setEnabled(game.id, $0) }))
                .toggleStyle(.switch).labelsHidden().tint(Theme.accent)
                .help(game.isEnabled ? "In rotation" : "Add to rotation")

            if game.isCustom {
                Button(role: .destructive) { store.removeGame(game.id) } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).foregroundStyle(Theme.danger).help("Delete custom game")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .card(hover: hover, radius: 14)
        .onHover { hover = $0 }
    }
}

struct AddGameSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @Local private var name = ""
    @Local private var urlText = ""
    @Local private var symbol = "star.fill"
    @Local private var color = "#F97316"
    @Local private var isMust = false

    private let symbols = ["star.fill", "gamecontroller.fill", "puzzlepiece.extension.fill", "textformat.abc",
                           "globe.americas.fill", "brain.head.profile", "magnifyingglass", "music.note",
                           "film.fill", "number", "dice.fill", "sparkles"]
    private let colors = ["#F97316", "#EF4444", "#EC4899", "#A855F7", "#6366F1", "#3B82F6", "#14B8A6", "#22C55E", "#EAB308"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add a daily game").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
            TextField("Name (e.g. Heardle)", text: $name).textFieldStyle(.roundedBorder)
            TextField("https://…", text: $urlText).textFieldStyle(.roundedBorder)
            HStack(spacing: 6) {
                ForEach(symbols, id: \.self) { s in
                    Button { symbol = s } label: {
                        Image(systemName: s)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 7).fill(symbol == s ? Color.white.opacity(0.22) : Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 6) {
                ForEach(colors, id: \.self) { c in
                    Button { color = c } label: {
                        Circle().fill(Color(hex: c)).frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(.white, lineWidth: color == c ? 2 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }
            Toggle("Must-play every day", isOn: $isMust).toggleStyle(.switch).tint(Theme.accent)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add") { add() }.keyboardShortcut(.defaultAction).disabled(!valid)
            }
        }
        .padding(22)
        .frame(width: 440)
        .background(Theme.background)
    }

    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedURL != nil }

    private var parsedURL: URL? {
        var t = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty, !t.lowercased().hasPrefix("http") { t = "https://" + t }
        guard let u = URL(string: t), u.host != nil else { return nil }
        return u
    }

    private func add() {
        guard let u = parsedURL else { return }
        store.addCustomGame(name: name.trimmingCharacters(in: .whitespaces), url: u, symbol: symbol, color: color, isMust: isMust)
        dismiss()
    }
}
