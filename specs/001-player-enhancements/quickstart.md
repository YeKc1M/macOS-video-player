# Quickstart: Player Enhancements

**Date**: 2026-02-17
**Feature**: 001-player-enhancements

## Prerequisites

- macOS 14+
- Xcode 15+ (for Swift 5.9)
- A folder containing 3+ short video files (MP4, MOV, or M4V)

## Build & Run

```bash
swift build && swift run
```

Or for the .app bundle:

```bash
bash build.sh && open SuperpowersPlayer.app
```

## Manual Test Plan

### Test 1: Auto-Play Next Video (P1)

1. Launch the app.
2. Use **File → Open Folder** (Cmd+Shift+O) to load a folder with
   3+ videos.
3. Click the first video in the playlist to start playback.
4. Wait for the video to finish (or seek to near the end).
5. **Verify**: The next video starts playing automatically.
6. Navigate to the last video and let it finish.
7. **Verify**: The first video starts playing (wrap-around).

### Test 2: Progress Restoration on Auto-Advance

1. Load a folder with 3+ videos.
2. Play video 2 partially (e.g., to the 10-second mark).
3. Switch to video 1 and let it play to the end.
4. **Verify**: Video 2 auto-advances and resumes from ~10 seconds.

### Test 3: Playlist Progress Display (P2)

1. Load a folder with 3+ videos.
2. Watch video 1 for ~20 seconds, then switch to video 2.
3. Watch video 2 for ~10 seconds.
4. **Verify**: The playlist sidebar shows:
   - Video 1: "0:20 / [total duration]"
   - Video 2: "0:10 / [total duration]"
   - Video 3: "0:00 / [total duration]" (unwatched)
5. Let video 2 finish completely.
6. **Verify**: Video 2 shows as unwatched (progress cleared).

### Test 4: Keyboard Shortcuts — Seek (P3)

1. Play any video.
2. Press **Right arrow** → playback jumps forward 5 seconds.
3. Press **Left arrow** → playback jumps backward 5 seconds.
4. Seek to near 0:00 and press **Left arrow** → stays at 0:00.
5. Seek to near the end and press **Right arrow** → clamps to end.

### Test 5: Keyboard Shortcuts — Volume

1. Play any video.
2. Press **Up arrow** → volume increases (check controls bar).
3. Press **Down arrow** → volume decreases (check controls bar).
4. Press **Up arrow** repeatedly → volume caps at 100%.
5. Press **Down arrow** repeatedly → volume caps at 0%.

### Test 6: Keyboard Shortcuts — Speed

1. Play any video.
2. Press **]** → speed increases by 0.1x (check controls bar).
3. Press **[** → speed decreases by 0.1x (check controls bar).
4. Press **]** repeatedly → speed caps at 4.0x.
5. Press **[** repeatedly → speed caps at 0.1x.

### Test 7: Keyboard Shortcuts — Playlist Navigation

1. Load a folder with 3+ videos.
2. Start playing video 2.
3. Press **Page Down** → video 3 starts playing.
4. Press **Page Up** → video 2 starts playing.
5. Navigate to video 1, press **Page Up** → last video plays (wrap).
6. Navigate to last video, press **Page Down** → video 1 plays (wrap).

### Test 8: Edge Cases

1. Load a single video file. Press **Page Up** / **Page Down** →
   nothing happens.
2. Close all files (empty playlist). Press any shortcut key →
   nothing happens, no crash.
3. Load a folder, don't select any video. Press arrow keys →
   nothing happens.

## Expected File Changes

| File | Changes |
|------|---------|
| `PlayerViewModel.swift` | Add volume, playNext, playPrevious, loadPlaylistDurations |
| `ContentView.swift` | Add onKeyPress handlers, .focusable() |
| `ControlsView.swift` | Add volume level display |
| `PlaylistView.swift` | Add progress/duration display per entry |
| `VideoPlayerView.swift` | Possibly adjust focus behavior |
