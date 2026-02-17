# Data Model: Player Enhancements

**Date**: 2026-02-17
**Feature**: 001-player-enhancements

## Entity Changes

### VideoFile (existing — no structural changes)

```
VideoFile {
    url: URL            // File path (identity + Hashable key)
    name: String        // Display name (filename without extension)
    id: URL             // Identifiable conformance (same as url)
}
```

**No changes required.** Duration and progress are retrieved
externally (AVAsset and ProgressStore respectively), not stored
on the struct. This preserves Hashable/Identifiable stability.

### PlayerViewModel (existing — state additions)

New observable properties:

```
PlayerViewModel {
    // Existing state (unchanged)
    playlist: [VideoFile]
    currentVideo: VideoFile?
    isPlaying: Bool
    currentTime: Double
    duration: Double
    playbackSpeed: Float
    player: AVPlayer              // @ObservationIgnored

    // NEW: Volume state
    volume: Float = 1.0           // 0.0 – 1.0, step 0.05

    // NEW: Per-video duration cache
    videoDurations: [URL: Double] // Loaded async on playlist set
}
```

New methods:

```
// Volume control
increaseVolume()                  // volume += 0.05, clamped to 1.0
decreaseVolume()                  // volume -= 0.05, clamped to 0.0

// Playlist navigation
playNext()                        // Advance to next video (wraps)
playPrevious()                    // Go to previous video (wraps)

// Duration loading
loadPlaylistDurations()           // Async batch load via AVURLAsset
```

### ProgressStore (existing — no changes)

```
ProgressStore {
    static save(time: Double, for: URL)   // Existing
    static load(for: URL) -> Double       // Existing
    static clear(for: URL)                // Existing
}
```

No API changes needed. Existing methods are sufficient for all
new features (progress display reads via `load`, auto-advance
clears via `clear`).

## State Transitions

### Auto-Advance Flow

```
Video Playing
    │
    ▼ (AVPlayerItemDidPlayToEndTime)
Clear progress for finished video
    │
    ▼
Determine next video index
    │ (currentIndex + 1) % playlist.count
    ▼
selectVideo(nextVideo)
    │
    ▼ (existing selectVideo logic)
Restore saved progress (if any)
    │
    ▼
Auto-play starts
```

### Volume Adjustment Flow

```
Key Press (↑ or ↓)
    │
    ▼
Compute new volume (±0.05, clamped 0.0–1.0)
    │
    ▼
Update viewModel.volume
    │
    ▼
Set player.volume = newVolume
    │
    ▼
UI updates (ControlsView shows new level)
```

### Playlist Duration Loading Flow

```
Playlist set (openFile/openFolder)
    │
    ▼
loadPlaylistDurations() called
    │
    ▼ (TaskGroup, one task per VideoFile)
AVURLAsset(url:).load(.duration) for each
    │
    ▼
videoDurations[url] = seconds
    │
    ▼
PlaylistView re-renders with duration info
```

## Data Flow Summary

| Data | Source | Consumer | Update Trigger |
|------|--------|----------|----------------|
| Video duration | AVURLAsset (async) | PlaylistView | Playlist load |
| Saved progress | ProgressStore (UserDefaults) | PlaylistView | Timer tick, video switch |
| Current position | AVPlayer time observer | PlaylistView (for current video) | 0.5s interval |
| Volume level | PlayerViewModel.volume | ControlsView | Key press |
| Playback speed | PlayerViewModel.playbackSpeed | ControlsView | Key press or button |
