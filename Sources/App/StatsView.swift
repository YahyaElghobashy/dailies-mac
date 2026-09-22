import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store
    private let tiles = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Stats").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)

                LazyVGrid(columns: tiles, spacing: 12) {
                    StatTile(value: "\(store.currentStreak)", label: "Current streak", symbol: "flame.fill", color: Theme.accent)
                    StatTile(value: "\(store.bestStreak)", label: "Best streak", symbol: "trophy.fill", color: Theme.gold)
                    StatTile(value: "\(store.perfectDays)", label: "Perfect days", symbol: "star.fill", color: Theme.success)
                    StatTile(value: "\(store.totalCompletions)", label: "Puzzles solved", symbol: "checkmark.seal.fill", color: Color(hex: "#60A5FA"))
                    StatTile(value: "\(StreakEngine.daysPlayed(store.data))", label: "Days played", symbol: "calendar", color: Color(hex: "#C084FC"))
                    StatTile(value: "\(store.freezes)", label: "Streak freezes", symbol: "snowflake", color: Theme.freeze)
                }

                VStack(alignment: .leading, spacing: 10) {
                    title("Badges")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                        ForEach(Badge.all) { b in
                            let earned = b.earned(in: store.data, today: store.today)
                            VStack(spacing: 6) {
                                Image(systemName: b.symbol)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(earned ? Theme.flameGradient(streak: 7)
                                                            : LinearGradient(colors: [Theme.text3, Theme.text3], startPoint: .top, endPoint: .bottom))
                                Text(b.title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(earned ? Theme.text : Theme.text3)
                                Text(b.detail).font(.system(size: 10)).foregroundStyle(Theme.text3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14).padding(.horizontal, 8)
                            .card(tint: earned ? Theme.accent : nil)
                            .opacity(earned ? 1 : 0.55)
                            .help(earned ? "Earned" : "Locked — \(b.detail)")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    title("Per game")
                    VStack(spacing: 0) {
                        ForEach(store.prioritizedGames) { g in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.gameGradient(g.color))
                                    Image(systemName: g.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                }
                                .frame(width: 30, height: 30)
                                Text(g.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                                if g.isMust { Chip(text: "must", systemImage: "star.fill", color: Theme.gold) }
                                Spacer()
                                Chip(text: "\(store.gameStreak(g.id)) streak", systemImage: "flame.fill", color: Theme.accent)
                                Text("\(store.gameTotal(g.id)) solved")
                                    .font(.system(size: 11.5)).foregroundStyle(Theme.text3)
                                    .frame(width: 84, alignment: .trailing)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: 10) {
                    title("Last 26 weeks")
                    HeatmapView(weeks: 26, cell: 14).padding(16).card()
                }
            }
            .padding(24)
        }
    }

    private func title(_ t: String) -> some View {
        Text(t).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
    }
}
