# SuperpowersPlayer — macOS Video Player Design

## Overview

A native macOS video player built with SwiftUI + AVKit. Supports opening single video files or folders, displays a playlist sidebar, persists playback progress per file, and provides 0.1x-step speed control.

## Technology

- **UI**: SwiftUI (macOS 14+)
- **Video**: AVKit / AVFoundation (AVPlayer)
- **Storage**: UserDefaults (playback progress)
- **Distribution**: Local / direct run (no sandboxing)

## Architecture

MVVM with a single-window app.

### Components

| Component | Responsibility |
|-----------|---------------|
| `SuperpowersPlayerApp` | App entry point, menu commands |
| `ContentView` | Main layout: player + sidebar |
| `VideoPlayerView` | Wraps AVPlayer for video rendering |
| `PlaylistView` | Sidebar list of video files |
| `ControlsView` | Play/pause, seek bar, time, speed |
| `PlayerViewModel` | Central state management |
| `ProgressStore` | UserDefaults wrapper for playback positions |
| `VideoFile` | Model for a video file entry |

### Window Layout

```
┌─────────────────────────────────────────────────┐
│  ┌──────────────────────┬────────────────────┐  │
│  │                      │   Playlist Sidebar │  │
│  │   Video Player       │   ┌──────────────┐ │  │
│  │                      │   │ video1.mp4 ▶ │ │  │
│  │                      │   │ video2.mov   │ │  │
│  │                      │   │ video3.mp4   │ │  │
│  │                      │   └──────────────┘ │  │
│  ├──────────────────────┤                    │  │
│  │ advancement bar      │                    │  │
│  │ 02:34 / 15:20        │  Speed: [−] 1.0x [+] │
│  │ [◀◀] [▶/❚❚] [▶▶]   │                    │  │
│  └──────────────────────┴────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## Data Models

```swift
struct VideoFile: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
}
```

## State (PlayerViewModel)

```swift
class PlayerViewModel: ObservableObject {
    @Published var playlist: [VideoFile]
    @Published var currentVideo: VideoFile?
    @Published var isPlaying: Bool
    @Published var currentTime: Double      // seconds
    @Published var duration: Double          // seconds
    @Published var playbackSpeed: Double     // 0.1 ... 4.0, step 0.1
    
    let player: AVPlayer
    private let progressStore: ProgressStore
}
```

## Key Flows

### Open File / Folder
1. User triggers via menu or welcome screen button
2. `NSOpenPanel` presented (file mode or directory mode)
3. For folder: scan for files with extensions [mp4, mov, m4v]
4. Populate `playlist` array
5. If single file: auto-play it

### Select Video from Playlist
1. Save current video's progress via `ProgressStore`
2. Create new `AVPlayerItem` with selected file URL
3. Restore saved position (seek to stored time)
4. Begin playback

### Progress Persistence
- **Save triggers**: video switch, app quit, every 5s during playback
- **Storage**: `UserDefaults` keyed by file URL string → TimeInterval
- **Restore**: on video selection, seek to stored position

### Playback Speed
- Range: 0.1x to 4.0x, step 0.1
- `[−]` and `[+]` buttons modify `player.rate`
- Current speed displayed between buttons

## Edge Cases

- **File moved/deleted**: Show greyed out in playlist, skip on play attempt
- **Empty folder**: Show "No video files found" message
- **First launch**: Welcome state with Open File / Open Folder buttons
- **Video ends**: Stop playback, clear saved progress for that video

## File Structure

```
SuperpowersPlayer/
├── SuperpowersPlayerApp.swift       # App entry, menu commands
├── Models/
│   └── VideoFile.swift              # VideoFile model
├── ViewModels/
│   └── PlayerViewModel.swift        # Central state
├── Views/
│   ├── ContentView.swift            # Main layout
│   ├── VideoPlayerView.swift        # AVPlayer wrapper
│   ├── PlaylistView.swift           # Sidebar playlist
│   └── ControlsView.swift           # Playback controls
└── Services/
    └── ProgressStore.swift          # UserDefaults wrapper
```
