import Testing

@testable import {{ ProjectName }}Core

@Suite("GreetingService")
struct GreetingServiceTests {
    @Test("greets a name")
    func greetsAName() async throws {
        let greeting = try await DefaultGreetingService().greeting(for: "World")
        #expect(greeting.text == "Hello, World")
    }

    @Test("trims surrounding whitespace")
    func trimsWhitespace() async throws {
        let greeting = try await DefaultGreetingService().greeting(for: "  World \n")
        #expect(greeting.text == "Hello, World")
    }

    @Test("rejects a name that is only whitespace")
    func rejectsEmptyName() async {
        await #expect(throws: GreetingError.emptyName) {
            try await DefaultGreetingService().greeting(for: "   ")
        }
    }
}

@Suite("AppInfo")
struct AppInfoTests {
    @Test("formats version and build for display")
    func formatsVersion() {
        let info = AppInfo(name: "Example", version: "1.2.0", build: "34")
        #expect(info.versionDescription == "1.2.0 (34)")
    }
}
