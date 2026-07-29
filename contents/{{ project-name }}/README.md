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
just uitest  # drive the running .app through XCUITest
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
AccessibilityTests/              XCUITest suite driving the built .app
```

The split is deliberate:

- **Core imports no SwiftUI.** Anything in it is testable without a UI and reusable from a
  CLI or a daemon. Dependencies are protocols, so tests substitute stubs.
- **UI depends on Core, never the reverse.** View state is `@MainActor @Observable`; views
  are a function of that state.
- **The app shell is not part of the SwiftPM package.** That is what lets `swift build` and
  `swift test` run headless in CI with no Xcode project, no simulator, and no signing. Logic
  that creeps into `App/` becomes untestable — keep it to composition.

## Two kinds of test, on purpose

`Tests/` holds **Swift Testing** suites. They run under `swift test` in milliseconds with no
app, no window server and no Xcode project, because everything they cover is a library.

`AccessibilityTests/` holds an **XCUITest** suite. It launches the real `.app` and drives it
through the Accessibility API — the same interface VoiceOver uses. Run it with `just uitest`;
it needs a logged-in GUI session.

The split matters: anything provable without launching an app belongs in `Tests/`, where it
stays fast. `AccessibilityTests/` is for what only a running app can show.

### The bar it keeps

`testNoControlIsAnonymous` fails if any interactive control in the window announces nothing to
an assistive technology. That single rule is worth more than the individual assertions around
it, because **accessible and testable are the same property** — a control VoiceOver cannot name
is one a UI test cannot find either. Enforcing the first buys you the second.

Two details the rule had to get right, both learned the hard way:

- It checks the **label**, not the identifier. SwiftUI hands out identifiers of its own — an
  icon-only button silently inherits the SF Symbol's name — so a non-empty identifier is no
  evidence anyone chose it.
- It exempts identifiers prefixed `_XCUI:`. Those are AppKit's window chrome (close, minimize,
  zoom), which XCUITest labels for you; without the exemption the bar fails on every window.

## The Xcode project is generated

`{{ ProjectName }}.xcodeproj` is produced from `project.yml` by `just xcodeproj` and is not
committed. A checked-in project file is a merge-conflict magnet and effectively unreviewable.
Change `project.yml` instead and regenerate.

## Conventions worth keeping

- **Swift 6 language mode** is on (`swiftLanguageModes: [.v6]`). Data-race safety is enforced
  at compile time. Adopting it now is far cheaper than migrating later.
- **Swift Testing** (`@Test` / `#expect`) for the libraries; XCTest only where XCUITest
  requires it, in `AccessibilityTests/`.
- **Accessibility identifiers** on every control a test or assistive technology needs to find,
  declared once in `AccessibilityID` rather than as scattered string literals. The UI test
  target depends on the `{{ ProjectName }}UI` library so it refers to those constants by name —
  renaming one is a compile error, not a silently dead selector.
- **Explicit load states** (`LoadState`) rather than parallel `isLoading` / `error` / `value`
  flags, so illegal combinations cannot be represented.
- **Formatting** is swift-format's, configured by `.swift-format` to 4-space indentation so it
  agrees with `.editorconfig` instead of fighting it. `OrderedImports` is off: your module name
  is chosen when the project is generated, so no import order baked into a template can be
  lexicographically correct for every possible name. Switch it on and run `just fmt` once if
  you want it — this is your project now.

## Signing

The project signs ad-hoc (`CODE_SIGN_IDENTITY: "-"`) so `just app` works on a fresh clone
with no Apple Developer account. Set `DEVELOPMENT_TEAM` in `project.yml` and switch
`CODE_SIGN_STYLE` to `Automatic` when you need notarization.
