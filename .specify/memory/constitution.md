<!--
=== Sync Impact Report ===
Version change: [TEMPLATE] → 1.0.0
Modified principles:
  - [PRINCIPLE_1_NAME] → I. Zero Dependencies
  - [PRINCIPLE_2_NAME] → II. MVVM Single Source of Truth
  - [PRINCIPLE_3_NAME] → III. Memory Safety
  - [PRINCIPLE_4_NAME] → IV. Simplicity First
  - [PRINCIPLE_5_NAME] → V. Automatic Progress Persistence
Added sections:
  - Technology Constraints (was [SECTION_2_NAME])
  - Development Workflow (was [SECTION_3_NAME])
  - Governance (filled from template)
Removed sections: none
Templates requiring updates:
  - .specify/templates/plan-template.md ✅ no update needed
    (Constitution Check section is generic; gates derived at plan time)
  - .specify/templates/spec-template.md ✅ no update needed
    (No constitution-specific references)
  - .specify/templates/tasks-template.md ✅ no update needed
    (Task categorization is generic; no principle-specific task types)
  - .specify/templates/checklist-template.md ✅ no update needed
    (Generic template, no constitution references)
Follow-up TODOs: none
-->

# SuperpowersPlayer Constitution

## Core Principles

### I. Zero Dependencies

All functionality MUST use Apple system frameworks only
(SwiftUI, AVFoundation, AVKit, AppKit). No third-party
packages, SPM dependencies, or CocoaPods are permitted.

- `Package.swift` MUST NOT contain any `.package(url:)` entries.
- Import statements MUST reference only Apple-provided modules.
- If a capability requires a third-party library, the team MUST
  implement it using system APIs or justify an amendment to this
  principle via the Governance process.

**Rationale**: Eliminates supply-chain risk, reduces build
complexity, and ensures the app compiles with only Xcode and
the macOS SDK.

### II. MVVM Single Source of Truth

The application MUST follow the MVVM pattern with exactly one
`@Observable` view model (`PlayerViewModel`) owning all mutable
application state.

- Views MUST be `struct` types conforming to `View`.
- Views MUST NOT hold references to the view model; they receive
  data and emit actions via closures or `Binding` values.
- The view model MUST be annotated `@MainActor`.
- No additional stateful singletons, global variables, or
  secondary view models are permitted without an amendment.

**Rationale**: A single source of truth prevents state
synchronization bugs and makes the data flow predictable
and testable.

### III. Memory Safety

All code MUST follow strict memory-safety practices to prevent
leaks and crashes.

- Force unwraps (`!`) and force casts (`as!`) are FORBIDDEN.
- All closures capturing `self` (timers, observers,
  notifications, completion handlers) MUST use `[weak self]`.
- Observers and timers MUST be cleaned up in dedicated
  `cleanupObservers()` methods or `deinit`.
- `Double` values from AVFoundation MUST be checked with
  `.isFinite` before use.
- Guard-based early returns (`guard let ... else { return }`)
  MUST be used instead of nested optionals.

**Rationale**: AVFoundation works with long-lived observers and
asynchronous callbacks; disciplined memory management prevents
the retain cycles and crashes common in media applications.

### IV. Simplicity First

Every feature and abstraction MUST justify its existence.
The codebase MUST remain minimal and straightforward.

- YAGNI: Do not add functionality until it is needed.
- Services MUST be `struct` types with `static` methods (no
  unnecessary instances or dependency injection frameworks).
- No `try/catch` error handling unless recovery logic exists;
  failures return empty defaults (e.g., `[]`).
- Prefer inline solutions over new abstractions. A new type is
  warranted only when it encapsulates distinct responsibilities.
- Maximum ~100-character line width (soft limit).

**Rationale**: A small, focused codebase is easier to
understand, debug, and extend. Complexity is the primary
enemy of a solo/small-team project.

### V. Automatic Progress Persistence

The application MUST transparently save and restore playback
progress for every video without user intervention.

- Progress MUST be saved on: periodic timer tick, video switch,
  and application termination.
- Progress MUST be restored when a previously-played video is
  selected.
- Persistence MUST use `UserDefaults` via `ProgressStore` with
  keys prefixed `playback_progress_`.
- No user-facing "save" or "load" actions are permitted; the
  experience MUST be seamless.

**Rationale**: This is a core product requirement. Users expect
to resume where they left off without manual bookmarking.

## Technology Constraints

- **Language**: Swift 5.9, swift-tools-version:5.9
- **Platform**: macOS 14+ exclusively
  (`NSViewRepresentable`, not `UIViewRepresentable`)
- **Frameworks**: SwiftUI, AVFoundation, AVKit, AppKit
- **Build system**: Swift Package Manager (single executable
  target)
- **Concurrency**: `@MainActor` on view models; background work
  via `Task { @MainActor in }`
- **Inter-component communication**: `NotificationCenter` for
  menu commands to view model actions
- **Time handling**: `CMTime` with `preferredTimescale: 600`;
  periodic observer at 0.5s interval

## Development Workflow

- **Code organization**: `// MARK: -` sections within files
- **Naming**: `PascalCase` for types, `camelCase` for
  properties/methods/constants, file names match primary type
- **Imports**: One per line, alphabetically ordered, system
  frameworks only
- **Models**: `struct`, conforming to `Identifiable`/`Hashable`
  as needed
- **View models**: `@Observable final class`, `@MainActor`
- **Views**: Stateless `struct`, receive data via init, emit
  actions via closures
- **SF Symbols**: Use `Image(systemName:)` for all icons
- **Formatting**: 4-space indentation, opening braces on same
  line, trailing closures

## Governance

This constitution is the authoritative source of architectural
and development standards for SuperpowersPlayer. All code
contributions MUST comply with these principles.

- **Amendments**: Any change to a Core Principle requires:
  1. A written proposal documenting the change and rationale.
  2. An update to this file with incremented version number.
  3. A migration plan for existing code that violates the new
     principle (if applicable).
- **Versioning**: This constitution follows semantic versioning:
  - MAJOR: Principle removal or backward-incompatible
    redefinition.
  - MINOR: New principle or materially expanded guidance.
  - PATCH: Clarifications, wording, or non-semantic fixes.
- **Compliance**: Code reviews MUST verify adherence to all
  Core Principles. Violations MUST be resolved before merge.
- **Runtime guidance**: See `AGENTS.md` for detailed coding
  style, patterns, and conventions that implement these
  principles.

**Version**: 1.0.0 | **Ratified**: 2026-02-14 | **Last Amended**: 2026-02-17
