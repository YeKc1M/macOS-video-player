# Feature Specification: Player Enhancements

**Feature Branch**: `001-player-enhancements`
**Created**: 2026-02-17
**Status**: Draft
**Input**: Auto-play next video, playlist progress display, keyboard shortcuts

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Auto-Play Next Video (Priority: P1)

A user is watching a series of videos from a folder. When the current video
finishes, the next video in the playlist begins automatically. If the next
video was partially watched before, playback resumes from the saved position.
When the last video in the playlist finishes, playback wraps around to the
first video.

**Why this priority**: Continuous playback is the highest-impact usability
improvement. Without it, users must manually click every video — a major
friction point when watching a sequence of related files.

**Independent Test**: Load a folder with 3+ short videos. Play the first to
completion and verify the second starts automatically. Play the last to
completion and verify the first starts.

**Acceptance Scenarios**:

1. **Given** a playlist with 3 videos and video 1 is playing,
   **When** video 1 finishes,
   **Then** video 2 starts playing automatically.

2. **Given** video 2 was previously watched to the 30-second mark and then
   stopped, **When** video 1 finishes and auto-advances to video 2,
   **Then** video 2 resumes from the 30-second mark.

3. **Given** video 3 (the last in the playlist) is playing,
   **When** video 3 finishes,
   **Then** video 1 (the first in the playlist) starts playing.

4. **Given** a playlist with only 1 video,
   **When** that video finishes,
   **Then** it starts playing again from the beginning.

---

### User Story 2 - Playlist Progress Display (Priority: P2)

A user glances at the playlist sidebar and sees each video's stored playback
progress alongside its total duration. This lets them quickly identify which
videos are unwatched, partially watched, or fully watched.

**Why this priority**: Progress visibility directly supports the user's
workflow of tracking where they are in a series. It builds on the existing
progress persistence system and provides immediate informational value.

**Independent Test**: Load a folder with videos, watch some partially, and
verify the playlist shows progress/duration for each entry.

**Acceptance Scenarios**:

1. **Given** a playlist is loaded and some videos have saved progress,
   **When** the user views the playlist sidebar,
   **Then** each video entry shows its saved progress time and total duration
   (e.g., "12:30 / 45:00").

2. **Given** a video has never been played,
   **When** displayed in the playlist,
   **Then** it shows "0:00 / [total duration]" or just the total duration.

3. **Given** a video's progress was cleared (because it finished playing),
   **When** displayed in the playlist,
   **Then** it shows no saved progress (treated as unwatched).

4. **Given** a video is currently playing,
   **When** the user views the playlist,
   **Then** the displayed progress for that video updates in near-real-time.

---

### User Story 3 - Keyboard Shortcuts (Priority: P3)

A user controls playback entirely from the keyboard without reaching for
the mouse. Arrow keys handle seeking and volume; bracket keys adjust speed;
Page Up/Down switch between videos in the playlist.

**Why this priority**: Keyboard shortcuts are a power-user feature that
enhances efficiency. The app is already usable without them (mouse-based
controls exist), making this a strong P3 enhancement.

**Independent Test**: With a video playing, press each shortcut key and
verify the corresponding action occurs.

**Acceptance Scenarios**:

1. **Given** a video is playing at position 0:30,
   **When** the user presses the Right arrow key,
   **Then** playback jumps forward 5 seconds to 0:35.

2. **Given** a video is playing at position 0:30,
   **When** the user presses the Left arrow key,
   **Then** playback jumps backward 5 seconds to 0:25.

3. **Given** a video is playing at position 0:02,
   **When** the user presses the Left arrow key,
   **Then** playback jumps to 0:00 (does not go negative).

4. **Given** the player volume is at 50%,
   **When** the user presses the Up arrow key,
   **Then** the volume increases by one step.

5. **Given** the player volume is at 50%,
   **When** the user presses the Down arrow key,
   **Then** the volume decreases by one step.

6. **Given** the volume is at 100%,
   **When** the user presses the Up arrow key,
   **Then** the volume remains at 100% (does not exceed maximum).

7. **Given** the volume is at 0%,
   **When** the user presses the Down arrow key,
   **Then** the volume remains at 0% (does not go below minimum).

8. **Given** the playback speed is 1.0x,
   **When** the user presses the `]` key,
   **Then** the playback speed increases to 1.1x.

9. **Given** the playback speed is 1.0x,
   **When** the user presses the `[` key,
   **Then** the playback speed decreases to 0.9x.

10. **Given** the playback speed is at the maximum (4.0x),
    **When** the user presses the `]` key,
    **Then** the speed remains at 4.0x.

11. **Given** the playback speed is at the minimum (0.1x),
    **When** the user presses the `[` key,
    **Then** the speed remains at 0.1x.

12. **Given** a playlist with 3 videos and video 2 is currently playing,
    **When** the user presses Page Down,
    **Then** video 3 starts playing (progress saved for video 2).

13. **Given** a playlist with 3 videos and video 2 is currently playing,
    **When** the user presses Page Up,
    **Then** video 1 starts playing (progress saved for video 2).

14. **Given** the first video in the playlist is playing,
    **When** the user presses Page Up,
    **Then** the last video in the playlist starts playing (wrap around).

15. **Given** the last video in the playlist is playing,
    **When** the user presses Page Down,
    **Then** the first video in the playlist starts playing (wrap around).

16. **Given** a video is playing and the volume is at 50%,
    **When** the user presses the Up arrow key,
    **Then** the volume increases and the controls bar displays the updated
    volume level.

---

### Edge Cases

- What happens when the playlist contains only one video and PgUp/PgDn is
  pressed? Nothing happens; the current video continues playing uninterrupted.
- What happens when Left arrow is pressed at 0:00? Playback stays at 0:00.
- What happens when Right arrow is pressed within 5 seconds of the end?
  Playback jumps to the end of the video.
- What happens when a video file becomes unavailable (deleted/moved) during
  auto-advance? The system skips to the next available video. If no videos
  are available, playback stops.
- What happens when the playlist is empty and a keyboard shortcut is
  pressed? Nothing happens; no crash or error.
- What happens to progress display when a video's duration cannot be
  determined? The entry shows the filename only, without progress/duration.

## Clarifications

### Session 2026-02-17

- Q: Should the current volume level be visible to the user? → A: Yes, show volume level in the controls bar (e.g., percentage or icon).

## Requirements *(mandatory)*

### Functional Requirements

**Auto-Play:**

- **FR-001**: System MUST automatically begin playing the next video in the
  playlist when the current video finishes.
- **FR-002**: System MUST wrap playback from the last video to the first
  video in the playlist when the last video finishes.
- **FR-003**: When auto-advancing to a video with saved progress, system
  MUST resume playback from the saved position.
- **FR-004**: When auto-advancing to a video without saved progress, system
  MUST start playback from the beginning.
- **FR-005**: When a video finishes (manually or via auto-play), its saved
  progress MUST be cleared (marking it as fully watched).

**Playlist Progress Display:**

- **FR-006**: Each entry in the playlist sidebar MUST display the video's
  saved playback progress and total duration.
- **FR-007**: The progress display for the currently playing video MUST
  update in near-real-time (within 1 second of actual position change).
- **FR-008**: Videos with no saved progress MUST display as unwatched
  (showing 0:00 or omitting the progress portion).
- **FR-009**: The total duration for each video MUST be retrieved and
  displayed when the playlist is loaded.

**Keyboard Shortcuts:**

- **FR-010**: Left arrow key MUST seek backward 5 seconds from current
  position.
- **FR-011**: Right arrow key MUST seek forward 5 seconds from current
  position.
- **FR-012**: Seek MUST clamp to valid range (0 to video duration).
- **FR-013**: Up arrow key MUST increase player volume by one step.
- **FR-014**: Down arrow key MUST decrease player volume by one step.
- **FR-015**: Volume MUST clamp to valid range (0% to 100%).
- **FR-024**: The current volume level MUST be displayed in the controls
  bar so the user has visual feedback when adjusting volume.
- **FR-016**: `]` key MUST increase playback speed by 0.1x.
- **FR-017**: `[` key MUST decrease playback speed by 0.1x.
- **FR-018**: Playback speed MUST clamp to valid range (0.1x to 4.0x).
- **FR-019**: Page Down key MUST switch to the next video in the playlist.
- **FR-020**: Page Up key MUST switch to the previous video in the playlist.
- **FR-021**: PgUp/PgDn MUST wrap around at playlist boundaries (last→first,
  first→last).
- **FR-022**: All keyboard shortcuts MUST function without modifier keys
  (no Cmd, Ctrl, Shift, or Option required).
- **FR-023**: Keyboard shortcuts MUST be non-destructive when no video is
  loaded (no crash, no error).

### Key Entities

- **VideoFile**: Represents a playable video. Key attributes: file URL,
  display name, total duration, saved playback progress.
- **Playlist**: An ordered list of VideoFile entries. Supports sequential
  navigation (next/previous) with wrap-around at boundaries.
- **PlaybackProgress**: A stored mapping from video file URL to last-known
  playback position. Persisted across sessions.

### Assumptions

- Volume step size is 5% (0.05) per key press. This follows standard media
  player conventions. The existing app has no volume control, so this is a
  new capability.
- Keyboard shortcuts do not conflict with existing macOS system shortcuts.
  Arrow keys, brackets, and PgUp/PgDn are not reserved by the OS when a
  media app is focused.
- Video duration retrieval for playlist display is asynchronous; entries may
  briefly show without duration while loading.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can watch an entire folder of videos without manual
  intervention after loading the folder and pressing play once.
- **SC-002**: Users can identify the watch status of any video in the
  playlist within 2 seconds by glancing at the progress/duration display.
- **SC-003**: All 8 keyboard shortcuts respond within 200ms of key press
  with the correct action.
- **SC-004**: Playback position is accurately restored when auto-advancing
  to a previously partially-watched video (within 1 second of saved
  position).
- **SC-005**: Playlist wraps correctly in both directions (auto-play wraps
  last→first; PgUp at first wraps to last; PgDn at last wraps to first).
