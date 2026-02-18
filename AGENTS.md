# AGENTS.md — SuperpowersPlayer

## Project Overview

macOS native video player built with Swift 5.9, SwiftUI, and AVFoundation. Targets macOS 14+.
Single-target Swift Package (no external dependencies). MVVM architecture with `@Observable` view models.

## Build / Run / Test Commands

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release

# Run directly
swift run

# Build .app bundle (release + codesign)
bash build.sh

# Open built app
open SuperpowersPlayer.app

# Clean build artifacts
swift package clean

# Resolve dependencies (none currently, but for future use)
swift package resolve
```

**No test target exists yet.** If adding tests:
```bash
# Run all tests
swift test

# Run a single test class
swift test --filter VideoFileTests

# Run a single test method
swift test --filter VideoFileTests/testScanDirectory
```

**No linter is configured.** If adding SwiftLint:
```bash
swiftlint lint
swiftlint lint --fix
```

## Project Structure

```
Sources/SuperpowersPlayer/
  SuperpowersPlayerApp.swift    # @main App entry, menu commands
  AppDelegate.swift             # NSApplicationDelegate (activation policy)
  Models/
    VideoFile.swift             # Video file model, directory scanning
    KeyBinding.swift            # PlayerAction enum, StoredKeyBinding model
  ViewModels/
    PlayerViewModel.swift       # Core playback logic, AVPlayer management
  Views/
    ContentView.swift           # Root view: HSplitView (player + playlist)
    VideoPlayerView.swift       # NSViewRepresentable wrapping AVPlayerView
    ControlsView.swift          # Play/pause, seek bar, speed controls
    PlaylistView.swift          # Sidebar playlist with selection
    ShortcutSettingsView.swift  # Settings sheet for customizing keyboard shortcuts
    KeyRecorderView.swift       # Key capture button for recording shortcut keys
  Services/
    ProgressStore.swift         # UserDefaults-based playback position persistence
    ShortcutStore.swift         # UserDefaults-based keyboard shortcut persistence
```

## Architecture

- **Pattern**: MVVM. One `@Observable` view model (`PlayerViewModel`) owns all state.
- **State flow**: Views receive state via `@State private var viewModel = PlayerViewModel()` in `ContentView`. Child views receive values and closures — they do NOT hold references to the view model.
- **Concurrency**: `@MainActor` on view model. Background work dispatched via `Task { @MainActor in }`.
- **Inter-component communication**: `NotificationCenter` for menu commands → view model actions (see `Notification.Name` extensions in `SuperpowersPlayerApp.swift`).
- **Persistence**: `UserDefaults` via static methods on `ProgressStore`. Keys prefixed with `playback_progress_`.

## Code Style

### Swift Version & Platform
- Swift 5.9, swift-tools-version:5.9
- macOS 14+ only (`NSViewRepresentable`, not `UIViewRepresentable`)

### Formatting
- 4-space indentation
- Opening braces on same line: `func foo() {`
- Trailing closures used consistently
- No trailing commas in parameter lists (but present in array/dict literals)
- Max ~100 char line width (soft limit, not enforced)

### Naming
- **Types**: `PascalCase` — `VideoFile`, `PlayerViewModel`, `ControlsView`
- **Properties/methods**: `camelCase` — `currentTime`, `playbackSpeed`, `selectVideo(_:)`
- **Constants**: `camelCase` — `supportedExtensions`, `prefix`
- **Files**: Match primary type name — `PlayerViewModel.swift`
- **Directories**: Match layer name, PascalCase — `Views/`, `Models/`, `ViewModels/`, `Services/`

### Imports
- One import per line, alphabetically ordered
- System frameworks only (no third-party dependencies)
- Import only what's needed: `AVFoundation` not `AVKit` unless using `AVPlayerView`

### Types & Patterns
- **Models**: `struct`, conform to `Identifiable`, `Hashable` as needed
- **View Models**: `@Observable final class`, annotated `@MainActor`
- **Views**: `struct` conforming to `View`, stateless where possible
- **Services**: `struct` with `static` methods (no instances)
- Use `@ObservationIgnored` for non-observable stored properties in `@Observable` classes
- Use `let` for immutable view properties (data flows down via init params)

### MARK Comments
- Use `// MARK: -` to organize sections within files
- Sections: Observable State, File Opening, Video Selection, Playback Controls, etc.

### Documentation
- Use `///` doc comments for public/static API
- Inline `//` comments for implementation notes
- No doc comments needed for obvious SwiftUI `body` properties

### Error Handling
- Guard-based early returns: `guard let self, condition else { return }`
- Check `.isFinite` before using `Double` values from AVFoundation (durations, times)
- No `try/catch` — failures are handled by returning empty defaults (e.g., `[]`)
- No force unwraps (`!`) — use optional binding or nil coalescing

### Memory Management
- `[weak self]` in all closures that capture `self` (timers, observers, notifications)
- Clean up observers in dedicated `cleanupObservers()` methods
- Invalidate timers in `deinit`

### SwiftUI Patterns
- Closures passed to child views for actions: `onSelect: (VideoFile) -> Void`
- `Binding` created inline when needed (e.g., `ControlsView` seek bar)
- Use SF Symbols for icons: `Image(systemName: "play.fill")`
- Modifier chains: one per line when chain is long
- `.frame()`, `.padding()` with explicit values, not magic numbers

### AVFoundation
- `CMTime` with `preferredTimescale: 600`
- Periodic time observer at 0.5s interval
- KVO (`observe(\.status)`) for item readiness
- `NotificationCenter` for end-of-playback events

## Key Conventions

1. **No third-party dependencies** — use system frameworks only
2. **No force unwraps or force casts** — always use safe unwrapping
3. **Views are dumb** — they receive data and emit actions via closures
4. **Single source of truth** — `PlayerViewModel` is the only stateful object
5. **Persist progress automatically** — save on timer, on switch, and on termination
6. **Clean up resources** — always remove observers, invalidate timers

## Active Technologies
- Swift 5.9, swift-tools-version:5.9 + SwiftUI, AVFoundation, AVKit, AppKit (system only) (001-player-enhancements)
- UserDefaults via `ProgressStore` (existing) (001-player-enhancements)

## Recent Changes
- 001-player-enhancements: Added Swift 5.9, swift-tools-version:5.9 + SwiftUI, AVFoundation, AVKit, AppKit (system only)
