import XCTest

final class SweetArrowsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testPlayOpensTheFirstLevelAndBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let play = app.buttons["playButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()

        XCTAssertTrue(app.otherElements["board"].waitForExistence(timeout: 5)
            || app.descendants(matching: .any)["board"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["undoButton"].exists)

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
        XCTAssertTrue(app.buttons["undoButton"].waitForExistence(timeout: 5))
        attach(app, "2-level")
        app.buttons["backButton"].tap()
        app.buttons["Map"].tap()
        attach(app, "3-map")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
