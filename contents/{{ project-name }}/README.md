# {{ app_display_name }}

A macOS SwiftUI application.

## Requirements

- macOS {{ macos_deployment_target }} or later
- Xcode 26 or later
- [`just`](https://github.com/casey/just), [`xcodegen`](https://github.com/yonaskolb/XcodeGen)

## Getting started

```bash
just build   # build the SwiftPM libraries
just test    # run the Swift Testing suites
just app     # generate the Xcode project and build the .app
just run     # build and launch
```

`just` with no arguments builds. `just ci` runs what CI runs.

## Layout

```
Package.swift                    libraries only — no app target
project.yml                      XcodeGen definition of the .app bundle
Sources/{{ ProjectName }}Core/   domain and services; imports no SwiftUI
Sources/{{ ProjectName }}UI/     views and view state; depends on Core
App/                             the @main app shell, deliberately thin
Tests/                           Swift Testing suites for Core and UI
```

The split is deliberate:

- **Core imports no SwiftUI.** Anything in it is testable without a UI and reusable from a
  CLI or a daemon. Dependencies are protocols, so tests substitute stubs.
- **UI depends on Core, never the reverse.** View state is `@MainActor @Observable`; views
  are a function of that state.
- **The app shell is not part of the SwiftPM package.** That is what lets `swift build` and
  `swift test` run headless in CI with no Xcode project, no simulator, and no signing. Logic
  that creeps into `App/` becomes untestable — keep it to composition.

## The Xcode project is generated

`{{ ProjectName }}.xcodeproj` is produced from `project.yml` by `just xcodeproj` and is not
committed. A checked-in project file is a merge-conflict magnet and effectively unreviewable.
Change `project.yml` instead and regenerate.

## Conventions worth keeping

- **Swift 6 language mode** is on (`swiftLanguageModes: [.v6]`). Data-race safety is enforced
  at compile time. Adopting it now is far cheaper than migrating later.
- **Swift Testing** (`@Test` / `#expect`), not XCTest.
- **Accessibility identifiers** on every control a test or assistive technology needs to find,
  declared once in `AccessibilityID` rather than as scattered string literals. This is what
  makes UI automation possible later without reworking the views.
- **Explicit load states** (`LoadState`) rather than parallel `isLoading` / `error` / `value`
  flags, so illegal combinations cannot be represented.

## Signing

The project signs ad-hoc (`CODE_SIGN_IDENTITY: "-"`) so `just app` works on a fresh clone
with no Apple Developer account. Set `DEVELOPMENT_TEAM` in `project.yml` and switch
`CODE_SIGN_STYLE` to `Automatic` when you need notarization.
