# Tasks: Player Enhancements

**Input**: Design documents from `/specs/001-player-enhancements/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅

**Tests**: Not requested in specification. Manual verification via quickstart.md.

**Organization**: Tasks are grouped by user story to enable independent
implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

All paths relative to repository root. Source files are in
`Sources/SuperpowersPlayer/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No new project setup needed — existing project structure is
sufficient. This phase is intentionally empty.

**Checkpoint**: Existing project builds with `swift build` ✅

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add shared state and methods to `PlayerViewModel` that
multiple user stories depend on. MUST complete before any user story.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T001 Add `volume` observable property (Float, default 1.0) and `videoDurations` dictionary ([URL: Double]) to PlayerViewModel in Sources/SuperpowersPlayer/ViewModels/PlayerViewModel.swift
- [x] T002 Add `increaseVolume()` and `decreaseVolume()` methods (±0.05, clamped 0.0–1.0, rounded to 5% increments, sets `player.volume`) to PlayerViewModel in Sources/SuperpowersPlayer/ViewModels/PlayerViewModel.swift
- [x] T003 Add `playNext()` method to PlayerViewModel that finds the current video's index in `playlist`, computes `(index + 1) % playlist.count`, and calls `selectVideo()` on the next video. Guard: do nothing if playlist is empty or currentVideo is nil. In Sources/SuperpowersPlayer/ViewModels/PlayerViewModel.swift
- [x] T004 Add `playPrevious()` method to PlayerViewModel that finds the current video's index, computes `(index - 1 + playlist.count) % playlist.count`, and calls `selectVideo()` on the previous video. Guard: do nothing if playlist is empty or currentVideo is nil. In Sources/SuperpowersPlayer/ViewModels/PlayerViewModel.swift
- [x] T005 Add `loadPlaylistDurations()` async method to PlayerViewModel that uses `withTaskGroup` to load durations for all videos via `AVURLAsset(url:).load(.duration)`, storing results in `videoDurations`. Check `.isFinite` on each duration. Call this method at the end of `openFile()` and `openFolder()` after setting the playlist. In Sources/SuperpowersPlayer/ViewModels/PlayerViewModel.swift

**Checkpoint**: Foundation ready — `swift build` succeeds, new methods
exist on PlayerViewModel but are not yet wired to UI or end-of-playback.

---

## Phase 3: User Story 1 — Auto-Play Next Video (Priority: P1) 🎯 MVP

**Goal**: When a video finishes, automatically advance to the next video
in the playlist with wrap-around and progress restoration.

**Independent Test**: Load a folder with 3+ short videos. Play the first
to completion → second starts automatically. Play the last to completion
→ first starts.

### Implementation for User Story 1

- [x] T006 [US1] Modify the `endObserver` closure in `selectVideo()` to: (1) keep the existing `ProgressStore.clear(for:)` call, (2) remove the `self.isPlaying = false` line, (3) call `self.playNext()`. Since `playNext()` uses modular arithmetic `(index + 1) % count`, a single-video playlist wraps to index 0 and calls `selectVideo()` on the same video, which restarts from 0:00 (progress was just cleared). Multi-video playlists advance normally. In Sources/SuperpowersPlayer/ViewModels/PlayerViewModel.swift

**Checkpoint**: Auto-play works end-to-end. Build with `swift build`
and manually test per quickstart.md Test 1 and Test 2.

---

## Phase 4: User Story 2 — Playlist Progress Display (Priority: P2)

**Goal**: Each entry in the playlist sidebar shows saved playback progress
and total duration (e.g., "12:30 / 45:00").

**Independent Test**: Load a folder, watch some videos partially, verify
the playlist shows progress and duration for each entry.

### Implementation for User Story 2

- [x] T007 [US2] Update `PlaylistView` to accept new parameters: `videoDurations: [URL: Double]`, `currentTime: Double`, and `currentVideoURL: URL?`. In Sources/SuperpowersPlayer/Views/PlaylistView.swift
- [x] T008 [US2] Add a `formatTime(_ seconds: Double) -> String` helper function to PlaylistView (same format as ControlsView: "H:MM:SS" or "M:SS"). Display below each video name: for the currently playing video show `currentTime / duration`; for other videos show `ProgressStore.load(for: video.url) / videoDurations[video.url]`. If duration is nil, show filename only. In Sources/SuperpowersPlayer/Views/PlaylistView.swift
- [x] T009 [US2] Update `ContentView` to pass `videoDurations: viewModel.videoDurations`, `currentTime: viewModel.currentTime`, and `currentVideoURL: viewModel.currentVideo?.url` to `PlaylistView`. In Sources/SuperpowersPlayer/Views/ContentView.swift

**Checkpoint**: Playlist shows progress/duration. Build with `swift build`
and manually test per quickstart.md Test 3.

---

## Phase 5: User Story 3 — Keyboard Shortcuts (Priority: P3)

**Goal**: Users control playback entirely from keyboard: ←/→ seek ±5s,
↑/↓ volume ±5%, [/] speed ±0.1x, PgUp/PgDn prev/next video.

**Independent Test**: With a video playing, press each shortcut key and
verify the corresponding action occurs.

### Implementation for User Story 3

- [x] T010 [US3] Add volume display to ControlsView: accept `volume: Float` parameter, show volume icon (SF Symbol `speaker.wave.1`/`speaker.wave.2`/`speaker.wave.3` based on level, or `speaker.slash` when 0) and percentage text (e.g., "75%") in the controls bar, positioned between the time display and speed controls. In Sources/SuperpowersPlayer/Views/ControlsView.swift
- [x] T011 [US3] Update `ContentView` to pass `volume: viewModel.volume` to `ControlsView`. In Sources/SuperpowersPlayer/Views/ContentView.swift
- [x] T012 [US3] Add `.focusable()` modifier and all `onKeyPress` handlers to the outermost view in `ContentView.body` (on the `.frame(minWidth: 800, minHeight: 500)` view). Wire: `.leftArrow` → `seek(to: currentTime - 5)`, `.rightArrow` → `seek(to: currentTime + 5)`, `.upArrow` → `increaseVolume()`, `.downArrow` → `decreaseVolume()`, `.pageUp` → `playPrevious()`, `.pageDown` → `playNext()`, `characters: "[]"` → `decreaseSpeed()` / `increaseSpeed()`. All handlers return `.handled`. For `.pageUp` and `.pageDown` handlers, guard with `viewModel.playlist.count > 1` before calling `playPrevious()`/`playNext()` — single-video playlists should be a no-op per spec edge case. In Sources/SuperpowersPlayer/Views/ContentView.swift
- [x] T013 [US3] Verify AVPlayerView does not consume arrow key events. If it does, modify `VideoPlayerView` NSViewRepresentable to prevent the AVPlayerView from becoming first responder (e.g., subclass AVPlayerView and override `acceptsFirstResponder` to return false, or set `focusable` behavior). In Sources/SuperpowersPlayer/Views/VideoPlayerView.swift

**Checkpoint**: All keyboard shortcuts work. Build with `swift build`
and manually test per quickstart.md Tests 4–8.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and edge case hardening.

- [x] T014 Verify all edge cases from spec: empty playlist + key press → no crash; single video + PgUp/PgDn → no-op; Left at 0:00 → stays; Right near end → clamps. Build and run with `swift build && swift run`
- [x] T015 Run full quickstart.md validation (all 8 test scenarios) to confirm SC-001 through SC-005 pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: N/A — existing project
- **Foundational (Phase 2)**: T001–T005 must complete before any user story
- **User Story 1 (Phase 3)**: Depends on T003 (`playNext()`)
- **User Story 2 (Phase 4)**: Depends on T005 (`videoDurations`)
- **User Story 3 (Phase 5)**: Depends on T002–T004 (volume and nav methods)
  and T006 (auto-advance, for PgUp/PgDn behavior parity)
- **Polish (Phase 6)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2. No dependency on US2 or US3.
- **US2 (P2)**: Can start after Phase 2. No dependency on US1 or US3.
- **US3 (P3)**: Can start after Phase 2. Uses methods from Phase 2 directly.
  If PgUp/PgDn should match auto-advance behavior, implement after US1.

### Within Phase 2 (Foundational)

- T001 must complete before T002 (volume property needed for methods)
- T001 must complete before T005 (videoDurations property declaration)
- T003 and T004 can run in parallel after T001
- T002 can run in parallel with T003/T004 after T001
- T005 is independent of T002–T004

### Within Phase 5 (US3)

- T010 and T012 modify different files → can run in parallel
- T011 depends on T010 (needs new ControlsView parameter)
- T013 is independent (different file)

### Parallel Opportunities

```text
After T001 completes:
  Parallel: T002, T003, T004, T005

After Phase 2 completes:
  Parallel: US1 (T006), US2 (T007–T009)

Within US3:
  Parallel: T010, T012, T013
  Then: T011 (depends on T010)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (T001–T005)
2. Complete Phase 3: User Story 1 (T006)
3. **STOP and VALIDATE**: Test auto-play independently
4. Build and run app to verify

### Incremental Delivery

1. Complete Foundational → Foundation ready
2. Add US1 (T006) → Test auto-play → MVP!
3. Add US2 (T007–T009) → Test progress display
4. Add US3 (T010–T013) → Test keyboard shortcuts
5. Polish (T014–T015) → Full validation

---

## Notes

- All tasks modify existing files — no new files created
- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No test target exists — verification is manual per quickstart.md
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
