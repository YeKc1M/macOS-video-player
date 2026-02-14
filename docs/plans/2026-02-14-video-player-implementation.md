# SuperpowersPlayer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS video player with playlist sidebar, persistent playback progress, and speed control.

**Architecture:** Single-window SwiftUI app using MVVM. `@Observable` PlayerViewModel wraps AVPlayer. NSViewRepresentable wraps AVPlayerView. UserDefaults stores per-file playback positions.

**Tech Stack:** SwiftUI (macOS 14+), AVKit/AVFoundation, Swift Package Manager with AppDelegate activation fix for CLI builds.

**Build:** `swift build && swift run` or assemble `.app` bundle via build script.

---

### Task 1: Project Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/SuperpowersPlayer/SuperpowersPlayerApp.swift`
- Create: `Sources/SuperpowersPlayer/AppDelegate.swift`
- Create: `Sources/SuperpowersPlayer/Views/ContentView.swift`

**Step 1: Create `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SuperpowersPlayer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SuperpowersPlayer",
            path: "Sources/SuperpowersPlayer"
        ),
    ]
)
```

**Step 2: Create `Sources/SuperpowersPlayer/AppDelegate.swift`**

This is CRITICAL. Without it, running via `swift run` produces an unfocusable window with broken text fields.

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}
```

**Step 3: Create `Sources/SuperpowersPlayer/SuperpowersPlayerApp.swift`**

```swift
import SwiftUI

@main
struct SuperpowersPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Step 4: Create `Sources/SuperpowersPlayer/Views/ContentView.swift`**

Minimal placeholder:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("SuperpowersPlayer")
            .frame(minWidth: 800, minHeight: 500)
    }
}
```

**Step 5: Verify build and run**

Run: `swift build`
Expected: BUILD SUCCEEDED

Run: `swift run`
Expected: A window appears with "SuperpowersPlayer" text. Close it manually.

**Step 6: Commit**

```
feat: scaffold macOS SwiftUI app with SPM
```

---

### Task 2: VideoFile Model & ProgressStore

**Files:**
- Create: `Sources/SuperpowersPlayer/Models/VideoFile.swift`
- Create: `Sources/SuperpowersPlayer/Services/ProgressStore.swift`

**Step 1: Create `VideoFile.swift`**

```swift
import Foundation
import UniformTypeIdentifiers

struct VideoFile: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL

    init(url: URL) {
        self.id = url
        self.name = url.lastPathComponent
        self.url = url
    }

    /// Supported video UTTypes for NSOpenPanel filtering
    static let supportedTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]

    /// Supported file extensions for folder scanning
    static let supportedExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

    /// Check if a URL points to a supported video file
    static func isVideoFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Scan a directory for video files, sorted by name
    static func scanDirectory(_ url: URL) -> [VideoFile] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }

        var files: [VideoFile] = []
        for case let fileURL as URL in enumerator {
            if isVideoFile(fileURL) {
                files.append(VideoFile(url: fileURL))
            }
        }
        return files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
```

**Step 2: Create `ProgressStore.swift`**

```swift
import Foundation

struct ProgressStore {
    private static let prefix = "playback_progress_"

    /// Save playback position for a video URL
    static func save(time: Double, for url: URL) {
        guard time.isFinite && time > 0 else { return }
        UserDefaults.standard.set(time, forKey: key(for: url))
    }

    /// Load saved playback position for a video URL. Returns 0 if none saved.
    static func load(for url: URL) -> Double {
        UserDefaults.standard.double(forKey: key(for: url))
    }

    /// Clear saved progress for a video URL
    static func clear(for url: URL) {
        UserDefaults.standard.removeObject(forKey: key(for: url))
    }

    private static func key(for url: URL) -> String {
        prefix + url.absoluteString
    }
}
```

**Step 3: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```
feat: add VideoFile model and ProgressStore
```

---

### Task 3: PlayerViewModel

**Files:**
- Create: `Sources/SuperpowersPlayer/ViewModels/PlayerViewModel.swift`

**Step 1: Create `PlayerViewModel.swift`**

Key patterns from research:
- Use `@Observable` (not `ObservableObject`) for macOS 14+
- Use `@ObservationIgnored` for AVFoundation objects (they aren't observable)
- Always `removeTimeObserver` in cleanup
- Check `duration.isFinite` — it's NaN before asset loads
- Call `play()` first, then set `rate` (setting rate > 0 starts playback)

```swift
import AVFoundation
import AVKit
import Combine
import SwiftUI

@Observable
@MainActor
final class PlayerViewModel {
    // MARK: - Observable State
    var playlist: [VideoFile] = []
    var currentVideo: VideoFile?
    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var playbackSpeed: Float = 1.0

    // MARK: - Non-observable AVFoundation objects
    @ObservationIgnored private(set) var player = AVPlayer()
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var saveTimer: Timer?

    init() {
        // Save progress periodically every 5 seconds
        saveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveCurrentProgress()
            }
        }

        // Save progress on app termination
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveCurrentProgress()
            }
        }
    }

    // MARK: - File Opening

    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = VideoFile.supportedTypes

        if panel.runModal() == .OK, let url = panel.url {
            let video = VideoFile(url: url)
            playlist = [video]
            selectVideo(video)
        }
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a folder containing video files"

        if panel.runModal() == .OK, let url = panel.url {
            let files = VideoFile.scanDirectory(url)
            playlist = files
            if let first = files.first {
                selectVideo(first)
            }
        }
    }

    // MARK: - Video Selection

    func selectVideo(_ video: VideoFile) {
        // Save progress for current video before switching
        saveCurrentProgress()

        // Set new current video
        currentVideo = video

        // Load into player
        let item = AVPlayerItem(url: video.url)
        player.replaceCurrentItem(with: item)

        // Reset state
        currentTime = 0
        duration = 0
        isPlaying = false

        // Remove old observers
        cleanupObservers()

        // Observe item status to get duration and restore position
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self, item.status == .readyToPlay else { return }
                let dur = item.duration.seconds
                if dur.isFinite {
                    self.duration = dur
                }
                // Restore saved position
                let savedTime = ProgressStore.load(for: video.url)
                if savedTime > 0 && savedTime < dur {
                    let target = CMTime(seconds: savedTime, preferredTimescale: 600)
                    self.player.seek(to: target)
                    self.currentTime = savedTime
                }
                // Auto-play
                self.play()
            }
        }

        // Periodic time observer (0.5s interval)
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite {
                    self.currentTime = seconds
                }
            }
        }

        // End-of-playback observer
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = false
                // Clear progress since video finished
                if let video = self.currentVideo {
                    ProgressStore.clear(for: video.url)
                }
            }
        }
    }

    // MARK: - Playback Controls

    func play() {
        player.play()
        player.rate = playbackSpeed
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: Double) {
        let clamped = max(0, min(time, duration))
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target)
        currentTime = clamped
    }

    func increaseSpeed() {
        let newSpeed = min(playbackSpeed + 0.1, 4.0)
        setSpeed(newSpeed)
    }

    func decreaseSpeed() {
        let newSpeed = max(playbackSpeed - 0.1, 0.1)
        setSpeed(newSpeed)
    }

    private func setSpeed(_ speed: Float) {
        playbackSpeed = (speed * 10).rounded() / 10  // Round to 1 decimal
        if isPlaying {
            player.rate = playbackSpeed
        }
    }

    // MARK: - Progress Persistence

    private func saveCurrentProgress() {
        guard let video = currentVideo else { return }
        guard currentTime > 0 && currentTime.isFinite else { return }
        ProgressStore.save(time: currentTime, for: video.url)
    }

    // MARK: - Cleanup

    private func cleanupObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    deinit {
        saveTimer?.invalidate()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}
```

**Step 2: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: add PlayerViewModel with playback, speed, and progress persistence
```

---

### Task 4: VideoPlayerView (NSViewRepresentable)

**Files:**
- Create: `Sources/SuperpowersPlayer/Views/VideoPlayerView.swift`

**Step 1: Create `VideoPlayerView.swift`**

Key pattern: Wrap `AVPlayerView` via `NSViewRepresentable`. Use `controlsStyle = .none` since we build our own controls. Implement `dismantleNSView` to nil out player and prevent use-after-free.

```swift
import AVKit
import SwiftUI

struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none  // We provide our own controls
        view.showsFullScreenToggleButton = false
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player = nil
    }
}
```

**Step 2: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: add VideoPlayerView NSViewRepresentable wrapper
```

---

### Task 5: PlaylistView

**Files:**
- Create: `Sources/SuperpowersPlayer/Views/PlaylistView.swift`

**Step 1: Create `PlaylistView.swift`**

```swift
import SwiftUI

struct PlaylistView: View {
    let playlist: [VideoFile]
    let currentVideo: VideoFile?
    let onSelect: (VideoFile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Playlist")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            if playlist.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "film.stack")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No videos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Open a file or folder to begin")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(playlist, selection: Binding<VideoFile.ID?>(
                    get: { currentVideo?.id },
                    set: { id in
                        if let id, let video = playlist.first(where: { $0.id == id }) {
                            onSelect(video)
                        }
                    }
                )) { video in
                    HStack {
                        Image(systemName: currentVideo?.id == video.id ? "play.fill" : "film")
                            .foregroundStyle(currentVideo?.id == video.id ? .blue : .secondary)
                            .frame(width: 16)
                        Text(video.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
    }
}
```

**Step 2: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: add PlaylistView sidebar component
```

---

### Task 6: ControlsView

**Files:**
- Create: `Sources/SuperpowersPlayer/Views/ControlsView.swift`

**Step 1: Create `ControlsView.swift`**

```swift
import SwiftUI

struct ControlsView: View {
    let isPlaying: Bool
    let currentTime: Double
    let duration: Double
    let playbackSpeed: Float
    let onTogglePlayPause: () -> Void
    let onSeek: (Double) -> Void
    let onIncreaseSpeed: () -> Void
    let onDecreaseSpeed: () -> Void

    @State private var isSeeking = false
    @State private var seekTime: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            // Seek bar
            Slider(
                value: Binding(
                    get: { isSeeking ? seekTime : currentTime },
                    set: { newValue in
                        seekTime = newValue
                        isSeeking = true
                    }
                ),
                in: 0...max(duration, 0.01),
                onEditingChanged: { editing in
                    if !editing {
                        onSeek(seekTime)
                        isSeeking = false
                    }
                }
            )

            HStack {
                // Play/Pause button
                Button(action: onTogglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])

                // Time display
                Text("\(formatTime(isSeeking ? seekTime : currentTime)) / \(formatTime(duration))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                // Speed controls
                HStack(spacing: 4) {
                    Button(action: onDecreaseSpeed) {
                        Image(systemName: "minus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(playbackSpeed <= 0.1)

                    Text(String(format: "%.1fx", playbackSpeed))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 45)

                    Button(action: onIncreaseSpeed) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(playbackSpeed >= 4.0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
```

**Step 2: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: add ControlsView with seek bar, time display, and speed controls
```

---

### Task 7: ContentView — Assemble Layout

**Files:**
- Modify: `Sources/SuperpowersPlayer/Views/ContentView.swift` (replace placeholder)

**Step 1: Replace `ContentView.swift` with full layout**

```swift
import SwiftUI

struct ContentView: View {
    @State private var viewModel = PlayerViewModel()

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
                onSelect: { viewModel.selectVideo($0) }
            )
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}
```

**Step 2: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: assemble ContentView with player, controls, and playlist sidebar
```

---

### Task 8: Menu Commands

**Files:**
- Modify: `Sources/SuperpowersPlayer/SuperpowersPlayerApp.swift`

**Step 1: Add menu commands to the app**

Replace the existing `SuperpowersPlayerApp.swift`:

```swift
import SwiftUI

@main
struct SuperpowersPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open File...") {
                    NotificationCenter.default.post(name: .openFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Open Folder...") {
                    NotificationCenter.default.post(name: .openFolder, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
    static let openFolder = Notification.Name("openFolder")
}
```

**Step 2: Add notification listeners in ContentView**

Add `.onReceive` modifiers to ContentView. Update the body:

In `ContentView.swift`, add these modifiers to the outermost view (the `HSplitView`):

```swift
// After .frame(minWidth: 800, minHeight: 500)
.onReceive(NotificationCenter.default.publisher(for: .openFile)) { _ in
    viewModel.openFile()
}
.onReceive(NotificationCenter.default.publisher(for: .openFolder)) { _ in
    viewModel.openFolder()
}
```

**Step 3: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```
feat: add menu commands for Open File and Open Folder
```

---

### Task 9: Build Script & Integration Test

**Files:**
- Create: `build.sh`

**Step 1: Create build script**

```bash
#!/bin/bash
set -euo pipefail

APP_NAME="SuperpowersPlayer"
BUNDLE_ID="com.superpowers.player"
VERSION="1.0.0"

echo "Building ${APP_NAME}..."

# Build release binary
swift build -c release

# Create .app bundle
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# Copy binary
cp ".build/release/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

# Generate Info.plist
cat > "${APP_NAME}.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Superpowers Player</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.video</string>
</dict>
</plist>
EOF

# Ad-hoc codesign
codesign --force --sign - "${APP_NAME}.app"

echo ""
echo "Built ${APP_NAME}.app"
echo "Run with: open ${APP_NAME}.app"
echo "Or debug with: swift run"
```

**Step 2: Make executable**

Run: `chmod +x build.sh`

**Step 3: Build and verify**

Run: `swift build`
Expected: BUILD SUCCEEDED

Run: `./build.sh`
Expected: "Built SuperpowersPlayer.app"

**Step 4: Manual integration test**

Run: `swift run`

Test checklist:
1. Window appears with welcome state ("Open a video file or folder to get started")
2. Click "Open File..." — file picker appears, filtered to video files
3. Select a video — it plays in the main area with controls visible
4. Seek bar updates as video plays, time display shows current/total
5. Speed [−] and [+] buttons change speed in 0.1 increments
6. Click "Open Folder..." — folder picker appears
7. Select a folder with videos — playlist populates in sidebar
8. Click different video in playlist — switches video, resumes from saved position
9. Cmd+Q — reopening and selecting same video resumes from last position

**Step 5: Commit**

```
feat: add build script for .app bundle creation
```

---

## File Structure Summary

```
SuperpowersPlayer/
├── Package.swift
├── build.sh
├── docs/plans/
│   ├── 2026-02-14-video-player-design.md
│   └── 2026-02-14-video-player-implementation.md
├── requirement.md
└── Sources/SuperpowersPlayer/
    ├── SuperpowersPlayerApp.swift
    ├── AppDelegate.swift
    ├── Models/
    │   └── VideoFile.swift
    ├── ViewModels/
    │   └── PlayerViewModel.swift
    ├── Views/
    │   ├── ContentView.swift
    │   ├── VideoPlayerView.swift
    │   ├── PlaylistView.swift
    │   └── ControlsView.swift
    ├── Services/
    │   └── ProgressStore.swift
    └── build.sh
```

## Key Technical Decisions

1. **`@Observable` over `ObservableObject`**: macOS 14+ allows the modern Observation framework. Simpler, no `@Published` needed.
2. **`NSViewRepresentable` + `AVPlayerView`**: Full control over video rendering. `controlsStyle = .none` since we build custom controls.
3. **`controlsStyle = .none`**: We use our own `ControlsView` for consistent UX and speed control.
4. **`addPeriodicTimeObserver` at 0.5s**: Balances UI responsiveness with performance.
5. **AppDelegate activation fix**: Required for `swift run` — without it, window is unfocusable.
6. **Notification-based menu commands**: SwiftUI `.commands` modifier doesn't have direct access to `@State` in `ContentView`, so we bridge via `NotificationCenter`.
7. **Speed rounding**: `(speed * 10).rounded() / 10` prevents floating-point drift (e.g., 1.0000000001).
