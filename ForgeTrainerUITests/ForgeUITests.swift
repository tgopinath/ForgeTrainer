import XCTest

/// Walks through every screen like a user and saves a screenshot at each step.
/// Set SCREENSHOT_DIR (TEST_RUNNER_SCREENSHOT_DIR from xcodebuild) to also write PNGs to disk.
final class ForgeUITests: XCTestCase {
    private let app = XCUIApplication()
    private var step = 0

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["-uiTestReset"]
    }

    private func shot(_ name: String) {
        step += 1
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = String(format: "%02d-%@", step, name)
        a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? s.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(a.name! + ".png"))
        }
    }

    private func tab(_ name: String) {
        app.tabBars.buttons[name].tap()
        sleep(1)
    }

    private func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
    }

    private func type(into field: XCUIElement, _ text: String) {
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(text)
    }

    func testEveryScreen() throws {
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        sleep(1)

        // Example data tour
        shot("today-example")
        app.swipeUp(); sleep(1); shot("today-example-scrolled")
        app.swipeDown(); app.swipeDown()

        let firstExercise = app.buttons["Romanian Deadlift"].firstMatch
        if firstExercise.waitForExistence(timeout: 3) {
            firstExercise.tap(); sleep(2); shot("exercise-detail")
            app.swipeDown(velocity: .fast); sleep(1)
        }

        tab("Plan"); shot("plan")
        app.swipeUp(); sleep(1); shot("plan-scrolled")

        tab("Progress"); shot("progress")
        app.swipeUp(); sleep(1); shot("progress-scrolled")
        app.swipeUp(); sleep(1); shot("progress-scrolled-2")

        tab("Coach")
        let review = app.buttons["Review my last week"]
        if review.waitForExistence(timeout: 3) {
            review.tap()
            sleep(8)
        }
        shot("coach")

        // Set a real goal
        tab("Today")
        app.buttons["Your goal"].tap()
        sleep(1)
        button(containing: "Lose fat").tap()
        shot("goal-top")
        app.swipeUp(); sleep(1)
        let current = app.textFields["currentWeight"]
        XCTAssertTrue(current.waitForExistence(timeout: 3))
        type(into: current, "82")
        type(into: app.textFields["targetWeight"], "76")
        app.buttons["Done"].firstMatch.tap()
        sleep(1); shot("goal-filled")
        app.swipeUp()
        let build = app.buttons["Build my plan"]
        XCTAssertTrue(build.waitForExistence(timeout: 3))
        build.tap()
        sleep(2); shot("today-real")

        // Train
        let start = button(containing: "Start workout")
        XCTAssertTrue(start.waitForExistence(timeout: 3), "Today should have a workout (Mon/Wed/Fri default)")
        start.tap()
        allowNotificationsIfAsked()
        sleep(2); shot("workout")

        let weight = app.textFields.element(boundBy: 0)
        if weight.waitForExistence(timeout: 3) {
            type(into: weight, "60")
            app.buttons["Done"].firstMatch.tap()
        }
        let set1 = app.buttons["Mark set 1 done"].firstMatch
        XCTAssertTrue(set1.waitForExistence(timeout: 3))
        set1.tap()
        app.buttons["Mark set 2 done"].firstMatch.tap()
        sleep(1); shot("workout-rest-timer")
        app.swipeUp(); sleep(1); shot("workout-scrolled")

        app.buttons["Finish"].tap()
        sleep(2); shot("today-done")

        // Log weight
        tab("Progress")
        let w = app.textFields["weightInput"]
        if w.waitForExistence(timeout: 3) {
            type(into: w, "81.4")
            app.buttons["Done"].firstMatch.tap()
            button(containing: "Log").tap()
            sleep(1)
        }
        shot("progress-real")

        tab("Plan"); shot("plan-real")
        button(containing: "Back Squat").firstMatch.tap()
        sleep(2); shot("plan-edit-sheet")
    }

    /// Clean captures for the portfolio (run with SCREENSHOT_DIR set).
    func testPortfolioShots() throws {
        app.launchArguments = ["-uiTestReset", "-portfolioDemo"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        sleep(2); shot("p-today")

        app.buttons["Romanian Deadlift"].firstMatch.tap()
        sleep(2); shot("p-detail")
        app.swipeDown(velocity: .fast); sleep(1)

        tab("Plan"); shot("p-plan")
        tab("Progress"); shot("p-progress")
        tab("Coach")
        app.buttons["Review my last week"].tap()
        sleep(6); shot("p-coach")

        tab("Today")
        button(containing: "Start workout").tap()
        allowNotificationsIfAsked()
        sleep(1)
        app.buttons["Mark set 1 done"].firstMatch.tap()
        app.buttons["Mark set 2 done"].firstMatch.tap()
        sleep(1); shot("p-workout")
    }
}
