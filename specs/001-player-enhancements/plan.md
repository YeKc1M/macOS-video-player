# Implementation Plan: Player Enhancements

**Branch**: `001-player-enhancements` | **Date**: 2026-02-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-player-enhancements/spec.md`

## Summary

Add three capabilities to the SuperpowersPlayer macOS video player:
(1) auto-advance to the next video when the current one finishes, with
playlist wrap-around and saved-progress restoration; (2) display each
video's stored progress and total duration in the playlist sidebar;
(3) keyboard shortcuts for seek (←/→ ±5s), volume (↑/↓ ±5%), speed
([/] ±0.1x), and playlist navigation (PgUp/PgDn). All changes are
confined to existing files — primarily `PlayerViewModel.swift`,
`PlaylistView.swift`, `ControlsView.swift`, and `ContentView.swift` —
with no new dependencies.

## Technical Context

**Language/Version**: Swift 5.9, swift-tools-version:5.9
**Primary Dependencies**: SwiftUI, AVFoundation, AVKit, AppKit (system only)
**Storage**: UserDefaults via `ProgressStore` (existing)
**Testing**: No test target exists; manual verification
**Target Platform**: macOS 14+
**Project Type**: Single executable (Swift Package Manager)
**Performance Goals**: Keyboard shortcuts respond within 200ms;
playlist progress updates within 1s of position change
**Constraints**: Zero third-party dependencies; single view model
(`PlayerViewModel`) owns all mutable state
**Scale/Scope**: Single-user desktop app; playlists of ~50-200 videos

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Zero Dependencies | ✅ PASS | All features use system frameworks only |
| II. MVVM Single Source of Truth | ✅ PASS | All new state (volume, next/prev logic) added to `PlayerViewModel`; views receive data via closures |
| III. Memory Safety | ✅ PASS | New observers/closures will use `[weak self]`, guard-based returns, `.isFinite` checks |
| IV. Simplicity First | ✅ PASS | No new types or abstractions required; extends existing patterns |
| V. Automatic Progress Persistence | ✅ PASS | Auto-advance restores saved progress; progress cleared on finish (FR-005); progress displayed in playlist |

**Gate result: ALL PASS** — no violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/001-player-enhancements/
├── plan.md              # This file
├── research.md          # Phase 0: keyboard handling + duration retrieval research
├── data-model.md        # Phase 1: entity/state changes
├── quickstart.md        # Phase 1: manual test guide
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
Sources/SuperpowersPlayer/
├── SuperpowersPlayerApp.swift    # @main App entry (no changes expected)
├── AppDelegate.swift             # NSApplicationDelegate (no changes expected)
├── Models/
│   └── VideoFile.swift           # Add: duration property, async duration loading
├── ViewModels/
│   └── PlayerViewModel.swift     # Add: volume state, next/prev methods,
│                                 #       keyboard action handlers, auto-advance
├── Views/
│   ├── ContentView.swift         # Add: keyboard event interception
│   ├── VideoPlayerView.swift     # Possibly: prevent AVPlayerView key consumption
│   ├── ControlsView.swift        # Add: volume display indicator
│   └── PlaylistView.swift        # Add: progress/duration display per entry
└── Services/
    └── ProgressStore.swift       # No changes expected (existing API sufficient)
```

**Structure Decision**: Existing single-project layout. All changes
modify existing files within `Sources/SuperpowersPlayer/`. No new
files, directories, or targets required.

## Complexity Tracking

> No constitution violations — this section is intentionally empty.
