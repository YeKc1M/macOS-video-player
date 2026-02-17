# Research: Player Enhancements

**Date**: 2026-02-17
**Feature**: 001-player-enhancements

## R1: Keyboard Event Handling in SwiftUI macOS

### Decision

Use SwiftUI's `onKeyPress` modifier (macOS 14.0+) with `.focusable()`
for all keyboard shortcuts. No need for `NSEvent.addLocalMonitorForEvents`
or `NSView` subclassing.

### Rationale

- `onKeyPress` is available on macOS 14+ (our minimum target).
- It supports all required key types:
  - Arrow keys: `.leftArrow`, `.rightArrow`, `.upArrow`, `.downArrow`
  - Page keys: `.pageUp`, `.pageDown`
  - Character keys: `onKeyPress(characters: CharacterSet(charactersIn: "[]"))`
- Returns `.handled` to consume events or `.ignored` to pass through.
- The view MUST be `.focusable()` for `onKeyPress` to receive events.
- Works without modifier keys (unlike `.keyboardShortcut()`).

### Alternatives Considered

1. **NSEvent.addLocalMonitorForEvents**: Global key monitoring. Rejected
   because it bypasses SwiftUI's event system and requires manual
   cleanup. Also captures keys even when the app's window isn't focused
   in the right context.
2. **NSView subclass overriding keyDown**: Requires wrapping in
   `NSViewRepresentable`. More complex, less idiomatic SwiftUI.
3. **.keyboardShortcut()**: Requires modifier keys (Cmd, Ctrl, etc.).
   Does not support bare key presses.

### Key Implementation Pattern

```swift
ContentView()
    .focusable()
    .onKeyPress(.leftArrow) {
        viewModel.seek(to: viewModel.currentTime - 5)
        return .handled
    }
    .onKeyPress(.rightArrow) {
        viewModel.seek(to: viewModel.currentTime + 5)
        return .handled
    }
    .onKeyPress(.upArrow) {
        viewModel.increaseVolume()
        return .handled
    }
    .onKeyPress(.downArrow) {
        viewModel.decreaseVolume()
        return .handled
    }
    .onKeyPress(.pageUp) {
        viewModel.playPrevious()
        return .handled
    }
    .onKeyPress(.pageDown) {
        viewModel.playNext()
        return .handled
    }
    .onKeyPress(characters: CharacterSet(charactersIn: "[]")) { press in
        if press.characters == "[" {
            viewModel.decreaseSpeed()
        } else if press.characters == "]" {
            viewModel.increaseSpeed()
        }
        return .handled
    }
```

### AVPlayerView Key Conflict

AVPlayerView (used via `NSViewRepresentable` in `VideoPlayerView.swift`)
has built-in key handling for Space (play/pause) and arrow keys. To
prevent conflicts:
- Apply `onKeyPress` on the parent `ContentView`, which is higher in
  the responder chain.
- The `.focusable()` modifier on the parent view should capture events
  before they reach the AVPlayerView.
- If AVPlayerView still consumes events, the `NSViewRepresentable`
  wrapper can override `acceptsFirstResponder` to return `false`, or
  we can set the AVPlayerView's `allowsVideoFrameAnalysis = false` and
  manage focus explicitly.

## R2: Async Video Duration Retrieval

### Decision

Use `AVURLAsset` with the async `load(.duration)` method (available
macOS 13+/Swift 5.7+) to retrieve durations without loading videos
into AVPlayer. Use `TaskGroup` for concurrent retrieval with a
concurrency limit.

### Rationale

- `AVURLAsset` reads only file metadata, not the full video stream.
- The async `load(.duration)` API is the modern replacement for the
  deprecated synchronous `duration` property.
- `TaskGroup` allows parallel duration loading for faster playlist
  population.

### Alternatives Considered

1. **Synchronous `asset.duration`**: Deprecated in macOS 13+. Blocks
   the calling thread. Rejected for performance reasons with large
   playlists.
2. **Loading each video into AVPlayer temporarily**: Extremely heavy.
   Would create and destroy AVPlayerItem instances for each file.
3. **Using `MDItem` (Spotlight metadata)**: Only works if Spotlight
   has indexed the file. Unreliable for newly added or network files.

### Key Implementation Pattern

```swift
// Single file duration
func loadDuration(for url: URL) async -> Double? {
    let asset = AVURLAsset(url: url)
    do {
        let duration = try await asset.load(.duration)
        let seconds = duration.seconds
        return seconds.isFinite ? seconds : nil
    } catch {
        return nil
    }
}

// Batch loading for playlist
func loadAllDurations(for videos: [VideoFile]) async -> [URL: Double] {
    await withTaskGroup(of: (URL, Double?).self) { group in
        for video in videos {
            group.addTask {
                let dur = await self.loadDuration(for: video.url)
                return (video.url, dur)
            }
        }
        var results: [URL: Double] = [:]
        for await (url, duration) in group {
            if let duration {
                results[url] = duration
            }
        }
        return results
    }
}
```

### Performance Notes

- `AVURLAsset.load(.duration)` reads only the file header/container
  metadata. For standard video formats (MP4, MOV, MKV), this is
  typically < 10ms per file.
- For a playlist of ~200 files, concurrent loading via `TaskGroup`
  should complete within 1-2 seconds.
- No explicit concurrency limit needed for local files; the OS
  manages file I/O scheduling.

## R3: AVPlayer Volume Control

### Decision

Use `AVPlayer.volume` property (Float, 0.0 to 1.0) for volume
control. Step size: 0.05 (5%) per key press.

### Rationale

- `AVPlayer.volume` is independent of system volume — it controls
  only the player's output level within the app.
- Float range 0.0–1.0 maps directly to 0%–100%.
- Step size of 0.05 provides 20 discrete levels, which is a good
  balance between granularity and quick adjustment.

### Alternatives Considered

1. **System volume control via MediaPlayer**: Would affect all audio
   on the Mac, not just the player. Rejected — user expects to control
   only this app's volume.

### Key Implementation Pattern

```swift
// In PlayerViewModel
var volume: Float = 1.0  // Default: 100%

func increaseVolume() {
    let newVolume = min(volume + 0.05, 1.0)
    volume = (newVolume * 20).rounded() / 20  // Snap to 5% increments
    player.volume = volume
}

func decreaseVolume() {
    let newVolume = max(volume - 0.05, 0.0)
    volume = (newVolume * 20).rounded() / 20
    player.volume = volume
}
```

## R4: Progress Display in Playlist

### Decision

Store durations in a dictionary on `PlayerViewModel` keyed by video
URL. Load durations asynchronously when a playlist is populated.
Display progress and duration in `PlaylistView` alongside each
video name.

### Rationale

- Durations are per-file metadata, not per-session state.
- Loading them once when the playlist is set avoids repeated I/O.
- The existing `ProgressStore.load(for:)` method retrieves saved
  progress per URL — no changes needed to the persistence layer.

### Alternatives Considered

1. **Store duration on VideoFile struct**: Would require making
   `VideoFile` mutable or adding an async initializer. Rejected
   because the struct is `Hashable`/`Identifiable` and used as a
   dictionary/list key — mutating it after creation complicates
   identity.
2. **Cache durations in ProgressStore**: Conflates two concerns
   (progress vs. metadata). Rejected for separation of concerns.

### Key Implementation Pattern

```swift
// In PlayerViewModel
var videoDurations: [URL: Double] = [:]

// Called after playlist is set
func loadPlaylistDurations() {
    Task {
        let durations = await loadAllDurations(for: playlist)
        self.videoDurations = durations
    }
}

// In PlaylistView — display per entry
let progress = ProgressStore.load(for: video.url)
let duration = videoDurations[video.url]
Text("\(formatTime(progress)) / \(formatTime(duration ?? 0))")
```
