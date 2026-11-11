import XCTest

final class SweetArrowsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testPlayStartsTheEndlessGame() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let play = app.buttons["playButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(app.descendants(matching: .any)["score"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Hint"].exists)
        XCTAssertTrue(app.buttons["Hammer"].exists)
        app.buttons["backButton"].tap()
        XCTAssertTrue(play.waitForExistence(timeout: 5))
    }

    /// Screenshots of the main screens, attached to the test report (handy for checking layouts
    /// on different simulators and as a start for App Store screenshots).
    @MainActor
    func testScreenshotsOfMainScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        attach(app, "1-home")
        app.buttons["playButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["score"].waitForExistence(timeout: 5))
        sleep(4)
        attach(app, "2-endless")
        app.buttons["backButton"].tap()
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
