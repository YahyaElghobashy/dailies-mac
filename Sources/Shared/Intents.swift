import AppIntents
import Foundation

/// Backs the check-circle buttons in the widget. Runs inside the widget extension process,
/// writes to the shared state file, and WidgetKit re-renders the timeline when it returns.
struct ToggleGameIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Daily Game"
    static var description = IntentDescription("Marks one of your daily games as done (or not done).")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Game ID")
    var gameID: String

    init() {}

    init(gameID: String) {
        self.gameID = gameID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        DebugLog.write("intent toggle \(gameID)")
        Store.shared.refreshFromDisk()
        Store.shared.toggle(gameID)
        return .result()
    }
}
