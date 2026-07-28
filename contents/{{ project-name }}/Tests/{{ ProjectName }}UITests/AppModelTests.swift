import Testing

@testable import {{ ProjectName }}Core
@testable import {{ ProjectName }}UI

/// Stubbing the service is the whole reason `GreetingService` is a protocol:
/// these run in milliseconds with no network and no UI.
private struct StubGreetingService: GreetingService {
    let result: Result<Greeting, GreetingError>

    func greeting(for name: String) async throws -> Greeting {
        try result.get()
    }
}

@MainActor
@Suite("AppModel")
struct AppModelTests {
    private func model(_ result: Result<Greeting, GreetingError>) -> AppModel {
        AppModel(
            appInfo: AppInfo(name: "Example", version: "1.0.0", build: "1"),
            greetingService: StubGreetingService(result: result)
        )
    }

    @Test("starts idle")
    func startsIdle() {
        let model = model(.success(Greeting(text: "Hello, Example")))
        guard case .idle = model.greeting else {
            Issue.record("expected .idle, got \(model.greeting)")
            return
        }
    }

    @Test("loads a greeting")
    func loadsGreeting() async {
        let model = model(.success(Greeting(text: "Hello, Example")))
        await model.loadGreeting(for: "Example")

        guard case .loaded(let greeting) = model.greeting else {
            Issue.record("expected .loaded, got \(model.greeting)")
            return
        }
        #expect(greeting.text == "Hello, Example")
    }

    @Test("surfaces a failure instead of throwing at the view")
    func surfacesFailure() async {
        let model = model(.failure(.emptyName))
        await model.loadGreeting(for: "")

        guard case .failed = model.greeting else {
            Issue.record("expected .failed, got \(model.greeting)")
            return
        }
    }
}
