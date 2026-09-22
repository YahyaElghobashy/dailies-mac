import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: Store
    private let columns = [GridItem(.adaptive(minimum: 290, maximum: 440), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderCard()

                let s = store.todayStatus
                if !store.mustGames.isEmpty {
                    section("Must-play", subtitle: "Required every day, no matter the goal", games: store.mustGames)
                }
                if !store.optionalGames.isEmpty {
                    let title = store.mustGames.isEmpty ? "Today's games" : "Your rotation"
                    let sub = store.mustGames.isEmpty
                        ? "Finish any \(s.goal) of \(store.enabledGames.count) to complete the day"
                        : "Finish \(s.goal) games in total (must-plays count) to complete the day"
                    section(title, subtitle: sub, games: store.optionalGames)
                }
                if store.enabledGames.isEmpty {
                    section("Today's games", subtitle: "", games: [])
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("This week", subtitle: nil)
                        WeekStrip()
                    }
                    .padding(16).card()

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Last 16 weeks", subtitle: nil)
                        HeatmapView(weeks: 16)
                    }
                    .padding(16).card()

                    Spacer(minLength: 0)
                }
            }
            .padding(24)
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private func section(_ title: String, subtitle: String, games: [Game]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title, subtitle: subtitle.isEmpty ? nil : subtitle)
            if games.isEmpty {
                Text("Nothing here yet — flip some games on in Library.")
                    .font(.system(size: 12)).foregroundStyle(Theme.text3)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).card()
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(games) { GameCard(game: $0) }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
            if let s = subtitle { Text(s).font(.system(size: 11.5)).foregroundStyle(Theme.text3) }
        }
    }
}

struct HeaderCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let s = store.todayStatus
        let streak = store.currentStreak
        let plan = store.remainingPlan

        HStack(spacing: 22) {
            HStack(spacing: 14) {
                FlameView(streak: streak, size: 46, atRisk: store.streakAtRisk)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(streak)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                    Text("day streak")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text3)
                }
            }
            .frame(minWidth: 150, alignment: .leading)

            MascotView(state: store.faceState, size: 92, animated: true)
                .help(store.faceState.caption)

            ZStack {
                ProgressRing(progress: s.progress, lineWidth: 9, complete: s.complete)
                VStack(spacing: 0) {
                    Text("\(s.done)/\(s.goal)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                    Text("goal").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(Theme.text3)
                }
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 9) {
                Text(store.headline)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(store.streakAtRisk ? Theme.danger : Theme.text)
                    .animation(.default, value: store.headline)

                HStack(spacing: 8) {
                    Chip(text: DayKey.pretty(store.today), systemImage: "calendar", color: Theme.text2)
                    Chip(text: store.goalLine, systemImage: "target", color: s.complete ? Theme.success : Theme.accent)
                    Chip(text: "Best \(store.bestStreak)", systemImage: "trophy.fill", color: Theme.gold)
                    Chip(text: "\(store.freezes) freeze\(store.freezes == 1 ? "" : "s")", systemImage: "snowflake", color: Theme.freeze)
                        .help("Earn a streak freeze every 7 days (max 2). A freeze automatically covers one missed day.")
                }

                HStack(spacing: 8) {
                    if let next = store.nextGame {
                        Button { store.play(next) } label: {
                            Label("Play \(next.name)", systemImage: "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        if plan.count > 1 {
                            Button { store.openAllRemaining() } label: {
                                Label("Open the \(plan.count) you need", systemImage: "square.stack.3d.up.fill")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .help(plan.map(\.name).joined(separator: ", "))
                        }
                    } else {
                        Button { store.copyShareCard() } label: {
                            Label("Share today", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    Button { store.copyShareCard() } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(SecondaryButtonStyle())
                        .help("Copy share card (Wordle-style emoji grid)")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .card(tint: s.complete ? Theme.success : nil)
    }
}
