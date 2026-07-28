import Observation
import {{ ProjectName }}Core

/// Explicit load states beat a pile of `isLoading` / `error` / `value`
/// booleans: the illegal combinations stop being representable, and the view
/// becomes a `switch` with no "what if both are set" branch.
public enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

/// View state for the root scene.
///
/// `@Observable` (the Observation framework) rather than `ObservableObject`:
/// SwiftUI tracks only the properties a view actually reads, so unrelated
/// changes stop invalidating the whole view.
///
/// `@MainActor` because this drives UI. Services it calls are `Sendable` and
/// run wherever they like; hopping back is the compiler's problem, not yours.
@MainActor
@Observable
public final class AppModel {
    public private(set) var greeting: LoadState<Greeting> = .idle
    public let appInfo: AppInfo

    private let greetingService: any GreetingService

    public init(
        appInfo: AppInfo = .fromBundle(),
        greetingService: any GreetingService = DefaultGreetingService()
    ) {
        self.appInfo = appInfo
        self.greetingService = greetingService
    }

    public func loadGreeting(for name: String) async {
        greeting = .loading
        do {
            greeting = .loaded(try await greetingService.greeting(for: name))
        } catch {
            greeting = .failed(String(describing: error))
        }
    }
}
