import SwiftUI
import {{ ProjectName }}Core
import {{ ProjectName }}UI

/// The app shell, deliberately thin.
///
/// Everything here is composition: build the dependencies, hand them to the
/// UI. Logic that creeps into this file cannot be tested by `swift test`,
/// because this target is not part of the SwiftPM package.
@main
struct {{ ProjectName }}App: App {
    @State private var model = AppModel(
        appInfo: .fromBundle(),
        greetingService: DefaultGreetingService()
    )

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        .defaultSize(width: 720, height: 480)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }
    }
}
