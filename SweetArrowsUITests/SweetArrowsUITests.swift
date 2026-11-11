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
}
