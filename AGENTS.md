# AGENTS.md

Repository guide for agentic coding in `cude-app`.
Primary stack: SwiftUI + SwiftData + Swift Testing + XCTest.

## Scope

- Covers coding conventions and practical command usage for this workspace.
- Keeps project requirements and architecture references in one place.
- Applies to app source under `cude-app/cude-app` and tests under
  `cude-app/cude-appTests`, `cude-app/cude-appUITests`.
- In conflicts, follow `CLAUDE.md` first for project workflow, then this file
  for style details.

## Document Index

- **Requirements**: `agent/requirements.md` records product and functional
  requirements.
- **Architecture**: `agent/architecture.md` records technical architecture and
  module mapping.
- **Task decomposition**: `agent/tasks/` contains Epic and Story planning docs.
- **CLAUDE instructions**: `CLAUDE.md` keeps runtime and workflow guidance.

When requirements or architecture evolve, update these two files first,
then adjust related implementation guidance in this file.

## Cursor / Copilot instructions

No Cursor rules exist in `.cursor/rules/`.
No Copilot rules exist in `.github/copilot-instructions.md`.
If either appears later, load and merge those rules before editing.

## Build, Test, and Lint Commands

Run all commands from repository root.

### Build

iOS simulator build:

```bash
xcodebuild -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

macOS build:

```bash
xcodebuild -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=macOS' build
```

### Tests

Run all unit tests:

```bash
xcodebuild test -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:cude-appTests
```

Run all UI tests:

```bash
xcodebuild test -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:cude-appUITests
```

Run one unit test:

```bash
xcodebuild test -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:cude-appTests/cude_appTests/example
```

Run one UI test:

```bash
xcodebuild test -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:cude-appUITests/cude_appUITests/testExample
```

List tests in the project:

```bash
xcodebuild -project cude-app/cude-app.xcodeproj -scheme cude-app \
  -destination 'platform=iOS Simulator,name=iPhone 16' -listTests
```

### Lint / quality

No strict config is currently committed. Optional checks if installed:

```bash
swiftlint lint --strict
```

```bash
swiftformat cude-app/cude-app
```

## Code Style Guidelines

### Imports

- Group imports at top, one per line.
- Prefer Apple modules first (`SwiftUI`, `SwiftData`, `Foundation` only when
  used).
- Avoid wildcard imports.
- Avoid adding modules not directly used in the file.

### Formatting

- Use 4 spaces for indentation.
- Use one blank line between logical blocks.
- Keep long method chains and view modifiers readable by breaking lines.
- Use trailing commas in multi-line collections.
- Keep file headers brief and consistent.

### Naming

- Types: `UpperCamelCase` (`ContentView`, `Item`).
- Properties, variables, methods: `lowerCamelCase`.
- View names should reflect purpose (`EmptyStateView`, `ItemRowView`).
- Functions with side effects should use verb phrases: `addItem`, `deleteItems`.
- Prefer explicit and specific names over abbreviations.

### Types and structure

- SwiftData models: mark with `@Model`, keep properties as `var` only when
  mutating by app logic.
- Keep each file focused: one main type per file unless closely coupled.
- For views, isolate reusable UI pieces into small subviews.
- Use `struct` for value-driven SwiftUI views unless identity is needed.

### SwiftUI conventions

- Keep state close to ownership.
- Use `@Query` for read flows and `modelContext` for mutations.
- Wrap platform-specific UI branches with explicit `#if os(iOS)` /
  `#if os(macOS)`.
- Prefer `.navigationSplitViewColumnWidth` and other cross-platform behavior to
  be explicit where needed.
- Keep side effects out of `body`; use actions and helpers.

### Error handling

- Do not swallow errors silently.
- Use `do { ... } catch { ... }` for recoverable failures.
- At startup, fatal failure is acceptable only for unrecoverable bootstrap
  state, matching existing startup patterns.
- Convert internal errors to user-facing feedback at UI boundaries.
- Return `Result` or throw typed errors for reusable service methods.

### Testing style

- Unit tests: `import Testing`, annotate with `@Test`, use `#expect(...)`.
- Keep tests focused and minimal.
- UI tests should set `continueAfterFailure = false` early.

### Platform and file-specific notes

- Keep iOS/macOS differences visible and deliberate.
- New `@Model` classes must also be registered in app schema.
- Preview helpers should use in-memory containers.
- Prefer safe navigation and deletion patterns when mutating lists.

### Agent workflow notes

- Verify command availability before test runs.
- Keep changes scoped and do not revert unrelated working tree edits.
- If uncertain, compile first then refactor.
