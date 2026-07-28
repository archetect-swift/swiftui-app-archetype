import SwiftUI

/// macOS apps are expected to have a Settings scene (⌘,). Shipping an empty
/// one from the start means the menu item is never missing, and the first
/// real preference has somewhere obvious to go.
public struct SettingsView: View {
    @AppStorage("general.launchAtLogin") private var launchAtLogin = false

    public init() {}

    public var body: some View {
        TabView {
            Form {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 420, height: 180)
    }
}

#Preview {
    SettingsView()
}
