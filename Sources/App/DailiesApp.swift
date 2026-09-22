import SwiftUI

@main
struct DailiesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = Store.shared

    var body: some Scene {
        Window("Dailies", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 880, minHeight: 580)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1060, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Games") {
                Button("Play Next Game") { store.playNext() }
                    .keyboardShortcut("p", modifiers: [.command])
                Button("Open All Remaining") { store.openAllRemaining() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Button("Copy Share Card") { store.copyShareCard() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(width: 700, height: 760)
                .background(Theme.background)
        }
    }
}
