# Customizable Keyboard Shortcuts Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow users to customize all 9 keyboard shortcuts via a Settings window accessible from the menu bar.

**Architecture:** Define a `PlayerAction` enum mapping to all 9 player actions. Store key bindings as `[PlayerAction: StoredKeyBinding]` in UserDefaults via a `ShortcutStore` service (following the existing `ProgressStore` pattern). Replace the 7 individual `.onKeyPress()` modifiers and the `.keyboardShortcut(.space)` in ContentView with a single catch-all `.onKeyPress(phases:)` handler that does runtime lookup against the binding map. Add a Settings window with a key recorder per action using `NSViewRepresentable`.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (NSEvent for key recording), UserDefaults

---

## Task 1: Create PlayerAction enum and StoredKeyBinding model

**Files:**
- Create: `Sources/SuperpowersPlayer/Models/KeyBinding.swift`

**Step 1: Create the model file**

```swift
import Foundation
import Carbon.HIToolbox

/// All customizable player actions.
enum PlayerAction: String, CaseIterable, Codable, Identifiable {
    case seekBackward
    case seekForward
    case volumeDown
    case volumeUp
    case previousVideo
    case nextVideo
    case decreaseSpeed
    case increaseSpeed
    case togglePlayPause

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .seekBackward:    return "Seek Backward"
        case .seekForward:     return "Seek Forward"
        case .volumeDown:      return "Volume Down"
        case .volumeUp:        return "Volume Up"
        case .previousVideo:   return "Previous Video"
        case .nextVideo:       return "Next Video"
        case .decreaseSpeed:   return "Decrease Speed"
        case .increaseSpeed:   return "Increase Speed"
        case .togglePlayPause: return "Play / Pause"
        }
    }

    var defaultBinding: StoredKeyBinding {
        switch self {
        case .seekBackward:    return StoredKeyBinding(keyCode: kVK_LeftArrow, displayName: "←")
        case .seekForward:     return StoredKeyBinding(keyCode: kVK_RightArrow, displayName: "→")
        case .volumeDown:      return StoredKeyBinding(keyCode: kVK_DownArrow, displayName: "↓")
        case .volumeUp:        return StoredKeyBinding(keyCode: kVK_UpArrow, displayName: "↑")
        case .previousVideo:   return StoredKeyBinding(keyCode: kVK_PageUp, displayName: "Page Up")
        case .nextVideo:       return StoredKeyBinding(keyCode: kVK_PageDown, displayName: "Page Down")
        case .decreaseSpeed:   return StoredKeyBinding(keyCode: kVK_ANSI_LeftBracket, displayName: "[")
        case .increaseSpeed:   return StoredKeyBinding(keyCode: kVK_ANSI_RightBracket, displayName: "]")
        case .togglePlayPause: return StoredKeyBinding(keyCode: kVK_Space, displayName: "Space")
        }
    }
}

/// A persistable key binding using hardware key codes.
struct StoredKeyBinding: Codable, Hashable {
    /// Hardware key code (from Carbon HIToolbox kVK_* constants).
    let keyCode: Int
    /// Human-readable name for display in the UI.
    let displayName: String

    /// Build a display name from an NSEvent's key code.
    static func displayName(forKeyCode keyCode: UInt16, characters: String?) -> String {
        switch Int(keyCode) {
        case kVK_LeftArrow:             return "←"
        case kVK_RightArrow:            return "→"
        case kVK_UpArrow:               return "↑"
        case kVK_DownArrow:             return "↓"
        case kVK_Space:                 return "Space"
        case kVK_Return:                return "Return"
        case kVK_Tab:                   return "Tab"
        case kVK_Delete:                return "Delete"
        case kVK_ForwardDelete:         return "Fwd Delete"
        case kVK_Escape:                return "Esc"
        case kVK_Home:                  return "Home"
        case kVK_End:                   return "End"
        case kVK_PageUp:                return "Page Up"
        case kVK_PageDown:              return "Page Down"
        case kVK_F1:                    return "F1"
        case kVK_F2:                    return "F2"
        case kVK_F3:                    return "F3"
        case kVK_F4:                    return "F4"
        case kVK_F5:                    return "F5"
        case kVK_F6:                    return "F6"
        case kVK_F7:                    return "F7"
        case kVK_F8:                    return "F8"
        case kVK_F9:                    return "F9"
        case kVK_F10:                   return "F10"
        case kVK_F11:                   return "F11"
        case kVK_F12:                   return "F12"
        default:
            if let characters, !characters.isEmpty {
                return characters.uppercased()
            }
            return "Key \(keyCode)"
        }
    }
}
```

**Step 2: Build**

Run: `swift build`
Expected: Build succeeds.

---

## Task 2: Create ShortcutStore service

**Files:**
- Create: `Sources/SuperpowersPlayer/Services/ShortcutStore.swift`

**Step 1: Create the store**

```swift
import Foundation

/// Persists custom keyboard shortcuts to UserDefaults.
/// Follows the same pattern as ProgressStore.
struct ShortcutStore {
    private static let key = "custom_keyboard_shortcuts"

    /// Save all bindings.
    static func save(_ bindings: [PlayerAction: StoredKeyBinding]) {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Load saved bindings, or nil if none saved.
    static func load() -> [PlayerAction: StoredKeyBinding]? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let bindings = try? JSONDecoder().decode(
                  [PlayerAction: StoredKeyBinding].self, from: data
              )
        else { return nil }
        return bindings
    }

    /// Clear all custom bindings (revert to defaults).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
```

**Step 2: Build**

Run: `swift build`
Expected: Build succeeds.

---

## Task 3: Add key bindings to PlayerViewModel and replace hardcoded handlers

**Files:**
- Modify: `Sources/SuperpowersPlayer/ViewModels/PlayerViewModel.swift`
- Modify: `Sources/SuperpowersPlayer/Views/ContentView.swift`
- Modify: `Sources/SuperpowersPlayer/Views/ControlsView.swift`

**Step 1: Add keyBindings property and action dispatch to PlayerViewModel**

Add after the `videoDurations` property:

```swift
var keyBindings: [PlayerAction: StoredKeyBinding] = {
    if let saved = ShortcutStore.load() {
        return saved
    }
    return Dictionary(
        uniqueKeysWithValues: PlayerAction.allCases.map { ($0, $0.defaultBinding) }
    )
}()
```

Add a new MARK section after Volume Control:

```swift
// MARK: - Keyboard Shortcut Handling

func handleKeyCode(_ keyCode: UInt16) -> Bool {
    let code = Int(keyCode)
    guard let action = keyBindings.first(where: { $0.value.keyCode == code })?.key
    else { return false }

    switch action {
    case .seekBackward:
        seek(to: currentTime - 5)
    case .seekForward:
        seek(to: currentTime + 5)
    case .volumeDown:
        decreaseVolume()
    case .volumeUp:
        increaseVolume()
    case .previousVideo:
        guard playlist.count > 1 else { return true }
        playPrevious()
    case .nextVideo:
        guard playlist.count > 1 else { return true }
        playNext()
    case .decreaseSpeed:
        decreaseSpeed()
    case .increaseSpeed:
        increaseSpeed()
    case .togglePlayPause:
        togglePlayPause()
    }
    return true
}

func updateKeyBindings(_ bindings: [PlayerAction: StoredKeyBinding]) {
    keyBindings = bindings
    ShortcutStore.save(bindings)
}

func resetKeyBindings() {
    keyBindings = Dictionary(
        uniqueKeysWithValues: PlayerAction.allCases.map { ($0, $0.defaultBinding) }
    )
    ShortcutStore.clear()
}
```

**Step 2: Replace ContentView's 7 onKeyPress modifiers with NSEvent monitor**

We need `NSEvent` monitoring because the catch-all `.onKeyPress(phases:)` provides `KeyPress.key` (a `KeyEquivalent`) which doesn't expose the hardware `keyCode`. Special keys like arrows, Page Up/Down are identified by `keyCode`, not by character. So we install a local event monitor.

Replace the entire ContentView with:

```swift
import SwiftUI

struct ContentView: View {
    @State private var viewModel = PlayerViewModel()
    @State private var keyMonitor: Any?

    var body: some View {
        HSplitView {
            // Left: Video player + controls
            VStack(spacing: 0) {
                if viewModel.currentVideo != nil {
                    VideoPlayerView(player: viewModel.player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    ControlsView(
                        isPlaying: viewModel.isPlaying,
                        currentTime: viewModel.currentTime,
                        duration: viewModel.duration,
                        playbackSpeed: viewModel.playbackSpeed,
                        volume: viewModel.volume,
                        onTogglePlayPause: { viewModel.togglePlayPause() },
                        onSeek: { viewModel.seek(to: $0) },
                        onIncreaseSpeed: { viewModel.increaseSpeed() },
                        onDecreaseSpeed: { viewModel.decreaseSpeed() }
                    )
                } else {
                    // Welcome state
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                        Text("SuperpowersPlayer")
                            .font(.title)
                        Text("Open a video file or folder to get started")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button("Open File...") {
                                viewModel.openFile()
                            }
                            Button("Open Folder...") {
                                viewModel.openFolder()
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 500)

            // Right: Playlist sidebar
            PlaylistView(
                playlist: viewModel.playlist,
                currentVideo: viewModel.currentVideo,
                videoDurations: viewModel.videoDurations,
                currentTime: viewModel.currentTime,
                currentVideoURL: viewModel.currentVideo?.url,
                onSelect: { viewModel.selectVideo($0) }
            )
        }
        .frame(minWidth: 800, minHeight: 500)
        .focusedValue(\.playerActions, PlayerActions(
            openFile: { viewModel.openFile() },
            openFolder: { viewModel.openFolder() },
            viewModel: viewModel
        ))
        .onAppear { installKeyMonitor() }
        .onDisappear { removeKeyMonitor() }
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't capture when a text field is focused (e.g., in settings)
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSText {
                return event
            }
            if viewModel.handleKeyCode(event.keyCode) {
                return nil // consumed
            }
            return event // pass through
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
```

**Step 3: Remove `.keyboardShortcut(.space)` from ControlsView**

In ControlsView.swift, remove line 44 (`.keyboardShortcut(.space, modifiers: [])`). The space bar is now handled by the NSEvent monitor via PlayerViewModel.

**Step 4: Update PlayerActions to include viewModel reference**

In SuperpowersPlayerApp.swift, update `PlayerActions`:

```swift
@MainActor
struct PlayerActions {
    let openFile: () -> Void
    let openFolder: () -> Void
    let viewModel: PlayerViewModel
}
```

**Step 5: Build**

Run: `swift build`
Expected: Build succeeds.

---

## Task 4: Create KeyRecorderView (NSViewRepresentable)

**Files:**
- Create: `Sources/SuperpowersPlayer/Views/KeyRecorderView.swift`

**Step 1: Create the key recorder**

```swift
import AppKit
import SwiftUI

/// A button that, when clicked, records the next key press and reports it back.
struct KeyRecorderView: View {
    let currentBinding: StoredKeyBinding
    let onRecord: (StoredKeyBinding) -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        Button(action: { startRecording() }) {
            Text(isRecording ? "Press a key…" : currentBinding.displayName)
                .frame(minWidth: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(isRecording ? .blue : .primary)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels recording
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let displayName = StoredKeyBinding.displayName(
                forKeyCode: event.keyCode,
                characters: event.charactersIgnoringModifiers
            )
            let binding = StoredKeyBinding(
                keyCode: Int(event.keyCode),
                displayName: displayName
            )
            onRecord(binding)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
```

**Step 2: Build**

Run: `swift build`
Expected: Build succeeds.

---

## Task 5: Create ShortcutSettingsView

**Files:**
- Create: `Sources/SuperpowersPlayer/Views/ShortcutSettingsView.swift`

**Step 1: Create the settings view**

```swift
import SwiftUI

struct ShortcutSettingsView: View {
    @State var bindings: [PlayerAction: StoredKeyBinding]
    let onSave: ([PlayerAction: StoredKeyBinding]) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(PlayerAction.allCases) { action in
                        HStack {
                            Text(action.displayName)
                                .frame(width: 140, alignment: .trailing)

                            KeyRecorderView(
                                currentBinding: bindings[action] ?? action.defaultBinding
                            ) { newBinding in
                                bindings[action] = newBinding
                                onSave(bindings)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }

            Divider()

            HStack {
                Button("Reset to Defaults") {
                    bindings = Dictionary(
                        uniqueKeysWithValues: PlayerAction.allCases.map {
                            ($0, $0.defaultBinding)
                        }
                    )
                    onReset()
                }

                Spacer()

                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 400, height: 420)
    }
}
```

**Step 2: Build**

Run: `swift build`
Expected: Build succeeds.

---

## Task 6: Wire Settings window into the app menu

**Files:**
- Modify: `Sources/SuperpowersPlayer/SuperpowersPlayerApp.swift`

**Step 1: Add Settings scene and menu item**

Replace the entire file:

```swift
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
        }

        Window("Keyboard Shortcuts", id: "settings") {
            if let viewModel = playerActions?.viewModel {
                ShortcutSettingsView(
                    bindings: viewModel.keyBindings,
                    onSave: { viewModel.updateKeyBindings($0) },
                    onReset: { viewModel.resetKeyBindings() }
                )
            } else {
                Text("Open a player window first.")
                    .frame(width: 300, height: 100)
            }
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Keyboard Shortcuts...") {
                    NSApp.sendAction(
                        Selector(("showSettingsWindow:")),
                        to: nil,
                        from: nil
                    )
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
```

Wait — using `Window` with `@FocusedValue` has issues (the focused value may be nil when the settings window gets focus). Let me use `@Environment(\.openWindow)` instead and pass the viewModel through the window ID approach. Actually, the simplest approach is to use a standalone settings window opened via `NSWindow` directly, which avoids the focused value problem entirely.

Let me revise. The cleanest approach for this single-window app: open the settings as a sheet on the main window, or use `openWindow` with shared state.

Actually, the simplest reliable pattern: make the settings window a sheet presented from ContentView.

**Revised Step 1: Update SuperpowersPlayerApp.swift**

Only add the Cmd+, menu item that posts a notification:

```swift
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
```

**Step 2: Add sheet presentation to ContentView**

Add to ContentView's `@State` properties:
```swift
@State private var showingSettings = false
```

Add `.sheet` and `.onReceive` to the body chain (on the `.frame(minWidth: 800, minHeight: 500)` view):
```swift
.sheet(isPresented: $showingSettings) {
    ShortcutSettingsView(
        bindings: viewModel.keyBindings,
        onSave: { viewModel.updateKeyBindings($0) },
        onReset: { viewModel.resetKeyBindings() }
    )
}
.onReceive(NotificationCenter.default.publisher(for: .showShortcutSettings)) { _ in
    showingSettings = true
}
```

**Step 3: Build**

Run: `swift build`
Expected: Build succeeds.

---

## Task 7: Verify and fix edge cases

**Step 1: Build and run**

Run: `swift build && swift run`

**Step 2: Manual verification checklist**

1. Default shortcuts all work (arrows, brackets, space, page up/down)
2. Cmd+, opens settings sheet
3. Click a shortcut row → "Press a key…" appears → press a key → binding updates
4. New binding works immediately (no restart needed)
5. Reset to Defaults restores original shortcuts
6. Esc during recording cancels without changing the binding
7. Close and reopen app → custom shortcuts persist
8. Empty playlist + any shortcut → no crash
9. Settings sheet doesn't intercept key events meant for recording

---

## Dependencies & Execution Order

```
Task 1 (KeyBinding model) ← no deps
Task 2 (ShortcutStore) ← depends on Task 1
Task 3 (ViewModel + ContentView) ← depends on Tasks 1, 2
Task 4 (KeyRecorderView) ← depends on Task 1
Task 5 (ShortcutSettingsView) ← depends on Tasks 1, 4
Task 6 (App menu wiring) ← depends on Tasks 3, 5
Task 7 (Verification) ← depends on all
```

Parallel opportunities:
- Tasks 1, 2 are sequential (2 depends on 1)
- Tasks 3 and 4 can run in parallel after Task 2
- Task 5 depends on Task 4
- Task 6 depends on Tasks 3 and 5
