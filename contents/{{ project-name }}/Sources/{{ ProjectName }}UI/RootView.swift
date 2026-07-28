import SwiftUI

/// Stable identifiers for anything a test — or an accessibility client —
/// needs to find. Hard-coding these as string literals at each call site is
/// how UI suites rot; naming them once means a rename is a compile error.
public enum AccessibilityID {
    public static let greetingText = "root.greeting.text"
    public static let greetingProgress = "root.greeting.progress"
    public static let reloadButton = "root.reload.button"
    public static let versionLabel = "root.version.label"
}

public struct RootView: View {
    @State private var model: AppModel

    public init(model: AppModel = AppModel()) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 16) {
            greetingContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Text(model.appInfo.versionDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.versionLabel)

                Spacer()

                Button("Reload") {
                    Task { await model.loadGreeting(for: model.appInfo.name) }
                }
                .accessibilityIdentifier(AccessibilityID.reloadButton)
            }
        }
        .padding()
        .task { await model.loadGreeting(for: model.appInfo.name) }
    }

    @ViewBuilder
    private var greetingContent: some View {
        switch model.greeting {
        case .idle, .loading:
            ProgressView()
                .accessibilityIdentifier(AccessibilityID.greetingProgress)
                .accessibilityLabel("Loading greeting")

        case .loaded(let greeting):
            Text(greeting.text)
                .font(.largeTitle)
                .accessibilityIdentifier(AccessibilityID.greetingText)

        case .failed(let message):
            ContentUnavailableView(
                "Could not load greeting",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .accessibilityIdentifier(AccessibilityID.greetingText)
        }
    }
}

#Preview {
    RootView()
}
