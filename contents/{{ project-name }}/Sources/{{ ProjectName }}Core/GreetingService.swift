import Foundation

/// A sample domain value. Replace it — the point is the shape: a `Sendable`
/// value type crossing an `async` boundary, behind a protocol.
public struct Greeting: Sendable, Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public enum GreetingError: Error, Equatable, Sendable {
    case emptyName
}

/// Services are protocols so the UI can be driven by a stub in tests without
/// a network, a clock, or a filesystem. `Sendable` is required for anything
/// crossing actor boundaries under Swift 6.
public protocol GreetingService: Sendable {
    func greeting(for name: String) async throws -> Greeting
}

public struct DefaultGreetingService: GreetingService {
    public init() {}

    public func greeting(for name: String) async throws -> Greeting {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GreetingError.emptyName }
        return Greeting(text: "Hello, \(trimmed)")
    }
}
