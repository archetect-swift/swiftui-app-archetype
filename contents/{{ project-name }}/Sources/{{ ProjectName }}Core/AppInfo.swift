import Foundation

/// Identity of the running application, resolved from the bundle.
///
/// Reading `Bundle.main` directly from a view is the usual shortcut and the
/// usual regret: it makes the view untestable and ties it to an app target.
/// Passing this value in keeps the UI a pure function of its inputs.
public struct AppInfo: Sendable, Equatable {
    public let name: String
    public let version: String
    public let build: String

    public init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }

    /// A display string of the form `1.2.0 (34)`.
    public var versionDescription: String {
        "\(version) (\(build))"
    }
}

extension AppInfo {
    /// Resolve from a bundle, falling back to placeholders when keys are
    /// absent — which is the normal case under `swift test`, where there is
    /// no app bundle at all.
    public static func fromBundle(_ bundle: Bundle = .main) -> AppInfo {
        let info = bundle.infoDictionary ?? [:]
        return AppInfo(
            name: info["CFBundleName"] as? String ?? "{{ app_display_name }}",
            version: info["CFBundleShortVersionString"] as? String ?? "0.0.0",
            build: info["CFBundleVersion"] as? String ?? "0"
        )
    }
}
