import SwiftUI

// MARK: - Focused Value Keys

struct FocusedPlayerActionsKey: FocusedValueKey {
    typealias Value = PlayerActions
}

extension FocusedValues {
    var playerActions: PlayerActions? {
        get { self[FocusedPlayerActionsKey.self] }
        set { self[FocusedPlayerActionsKey.self] = newValue }
    }
}

@MainActor
struct PlayerActions {
    let openFile: () -> Void
    let openFolder: () -> Void
    let viewModel: PlayerViewModel
}

extension Notification.Name {
    static let showShortcutSettings = Notification.Name("showShortcutSettings")
}

@main
struct SuperpowersPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedValue(\.playerActions) private var playerActions

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open File...") {
                    playerActions?.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Folder...") {
                    playerActions?.openFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Keyboard Shortcuts...") {
                    NotificationCenter.default.post(
                        name: .showShortcutSettings, object: nil
                    )
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
