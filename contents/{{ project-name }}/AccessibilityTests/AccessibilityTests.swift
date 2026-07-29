import {{ ProjectName }}UI
import XCTest

/// Black-box proofs driven through the Accessibility API by XCUITest.
///
/// These launch the real `.app`, so they are deliberately not part of
/// `swift test`: the Swift Testing suites cover logic in milliseconds, this
/// covers the one thing only a running app can show — that the interface is
/// reachable, and that every control announces itself.
@MainActor
final class AccessibilityTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() async throws {
        app?.terminate()
        app = nil
    }

    // MARK: - The declared identifiers resolve

    func testGreetingResolves() {
        let greeting = app.staticTexts[AccessibilityID.greetingText]
        XCTAssertTrue(greeting.waitForExistence(timeout: 10))
        // Static text carries its content in `value`, not `label`.
        XCTAssertEqual(greeting.value as? String, "Hello, {{ app_display_name }}")
    }

    func testReloadButtonDrivesTheGreeting() {
        let reload = app.buttons[AccessibilityID.reloadButton]
        XCTAssertTrue(reload.waitForExistence(timeout: 10))
        reload.click()

        let greeting = app.staticTexts[AccessibilityID.greetingText]
        XCTAssertTrue(greeting.waitForExistence(timeout: 10))
    }

    func testVersionLabelResolves() {
        let version = app.staticTexts[AccessibilityID.versionLabel]
        XCTAssertTrue(version.waitForExistence(timeout: 10))
    }

    // MARK: - The bar

    /// The rule this target exists to keep: if a control announces nothing,
    /// neither a person using VoiceOver nor a UI test can reach it. Accessible
    /// and testable are the same property, which is why enforcing the first
    /// buys you the second for free.
    func testNoControlIsAnonymous() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        let anonymous = anonymousControls(in: window)
        XCTAssertTrue(
            anonymous.isEmpty,
            """
            \(anonymous.count) control(s) announce nothing to an assistive \
            technology: \(anonymous.joined(separator: ", ")). Give each one a \
            title, or an explicit .accessibilityLabel(_:).
            """
        )
    }

    // MARK: - Helpers

    /// XCUITest reports element types as opaque integers, so the kinds worth
    /// checking are listed with the names a failure should print.
    private struct ControlKind {
        let type: XCUIElement.ElementType
        let name: String
    }

    /// Control types a person actually operates. Static text and groups are
    /// excluded on purpose: text carries its content in `value`, and SwiftUI
    /// emits structural groups nobody interacts with.
    private static let interactiveKinds: [ControlKind] = [
        ControlKind(type: .button, name: "button"),
        ControlKind(type: .checkBox, name: "checkbox"),
        ControlKind(type: .radioButton, name: "radio button"),
        ControlKind(type: .popUpButton, name: "pop-up button"),
        ControlKind(type: .menuButton, name: "menu button"),
        ControlKind(type: .toolbarButton, name: "toolbar button"),
        ControlKind(type: .comboBox, name: "combo box"),
        ControlKind(type: .textField, name: "text field"),
        ControlKind(type: .secureTextField, name: "secure text field"),
        ControlKind(type: .searchField, name: "search field"),
        ControlKind(type: .slider, name: "slider"),
        ControlKind(type: .stepper, name: "stepper"),
        ControlKind(type: .switch, name: "switch"),
        ControlKind(type: .disclosureTriangle, name: "disclosure triangle"),
        ControlKind(type: .segmentedControl, name: "segmented control"),
        ControlKind(type: .link, name: "link"),
    ]

    /// XCUITest synthesises identifiers for AppKit's window chrome — the
    /// close, minimize and zoom buttons. They belong to the window server, not
    /// to this app, and they carry no label, so they must be exempt or the bar
    /// fails on every window ever shown.
    private static let chromeIdentifierPrefix = "_XCUI:"

    /// Descriptions of the controls that announce nothing. Returned rather
    /// than asserted so one failure names every offender instead of stopping
    /// at the first.
    ///
    /// The rule is deliberately about `label`, not `identifier`: SwiftUI hands
    /// out incidental identifiers of its own — an icon-only button inherits the
    /// SF Symbol's name — so a non-empty identifier is no evidence that anyone
    /// chose it. The label is what an assistive technology actually reads.
    private func anonymousControls(in window: XCUIElement) -> [String] {
        Self.interactiveKinds.flatMap { kind in
            window.descendants(matching: kind.type).allElementsBoundByIndex
                .filter { !$0.identifier.hasPrefix(Self.chromeIdentifierPrefix) }
                .filter { $0.label.isEmpty }
                .map { describe($0, kind: kind) }
        }
    }

    /// Enough to find the offender in the source: its identifier if it has
    /// one, otherwise its kind and where it landed on screen.
    private func describe(_ element: XCUIElement, kind: ControlKind) -> String {
        let identifier = element.identifier
        guard identifier.isEmpty else { return "\(kind.name) '\(identifier)'" }
        return "unidentified \(kind.name) at \(element.frame.origin)"
    }
}
