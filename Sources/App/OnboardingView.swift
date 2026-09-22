import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                FlameView(streak: 7, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Dailies").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
                    Text("Your puzzle ritual, one click a day.").foregroundStyle(Theme.text2)
                }
            }
            step("1", "Play", "Click any card to open the game in your browser. Hit the circle when you've solved it.")
            step("2", "Keep the flame alive", "Set a daily goal in Settings (say, 5 of 13) and star your must-plays. Hit it and the day is perfect. Every 7 days you earn a streak freeze that quietly covers one missed day.")
            step("★", "Watch the visor", "Your pixel face keeps score: left lens ignites at half the goal, both at the goal — clear the whole rotation in one day and it goes full crazed.")
            step("3", "Put it on your desktop", "Right-click the desktop → Edit Widgets → search “Dailies”. Check games off right from the widget. The flame also lives in your menu bar.")
            step("4", "Get nudged", "A morning reminder and an evening “streak at risk” alert. Change the times in Settings.")
            HStack {
                Spacer()
                Button("Let's go") {
                    store.updateSettings { $0.hasOnboarded = true }
                    SuiteFlags.markOnboardingDone()
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 540)
        .background(Theme.background)
    }

    private func step(_ n: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Theme.accent))
                .foregroundStyle(.black)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                Text(body).font(.system(size: 12)).foregroundStyle(Theme.text2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
