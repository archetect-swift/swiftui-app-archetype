// swift-tools-version: 6.3
import PackageDescription

// The package holds ONLY libraries. The .app bundle is an Xcode target
// (see project.yml) that consumes them. Keeping the app shell out of SwiftPM
// is what lets `swift build` and `swift test` run fast and headless in CI,
// with no simulator, signing, or Xcode project involved.
let package = Package(
    name: "{{ ProjectName }}",
    platforms: [.macOS({{ macos_platform }})],
    products: [
        .library(name: "{{ ProjectName }}Core", targets: ["{{ ProjectName }}Core"]),
        .library(name: "{{ ProjectName }}UI", targets: ["{{ ProjectName }}UI"]),
    ],
    targets: [
        // Domain and services. Deliberately imports no SwiftUI — anything in
        // here is testable without a UI, and reusable from a CLI or a daemon.
        .target(name: "{{ ProjectName }}Core"),

        // Views and view state. Depends on Core, never the other way around.
        .target(name: "{{ ProjectName }}UI", dependencies: ["{{ ProjectName }}Core"]),

        .testTarget(name: "{{ ProjectName }}CoreTests", dependencies: ["{{ ProjectName }}Core"]),
        .testTarget(name: "{{ ProjectName }}UITests", dependencies: ["{{ ProjectName }}UI"]),
    ],
    // Swift 6 language mode: data-race safety is enforced at compile time.
    // Starting here is far cheaper than migrating later.
    swiftLanguageModes: [.v6]
)
