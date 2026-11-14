import XCTest

/// App Store screenshots in Dutch and English, from the demo account (see Demo.swift).
/// Only runs when the screenshots workflow sets SCREENSHOTS; the PNGs are written to
/// ~/appstore-shots on the Mac that runs the simulator.
final class ScreenshotTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        continueAfterFailure = true
        let environment = ProcessInfo.processInfo.environment
        guard environment["SCREENSHOTS"] != nil, let home = environment["SIMULATOR_HOST_HOME"] else {
            throw XCTSkip("Screenshots are only made by the screenshots workflow.")
        }
        folder = URL(fileURLWithPath: home).appendingPathComponent("appstore-shots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @MainActor
    func testAppStoreScreenshots() {
        for language in ["nl", "en"] {
            shootMainScreens(language)
            shootResult(language)
            shootGift(language)
        }
    }

    @MainActor
    private func launch(_ language: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-demo", "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "nl" ? "nl_NL" : "en_US",
        ] + extra
        app.launch()
        return app
    }

    @MainActor
    private func shootMainScreens(_ language: String) {
        let app = launch(language)
        let play = app.buttons["playButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        sleep(3)
        save("\(language)-2-home")

        app.buttons["shopButton"].tap()
        sleep(2)
        save("\(language)-4-shop")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        sleep(1)

        play.tap()
        XCTAssertTrue(app.descendants(matching: .any)["score"].waitForExistence(timeout: 10))
        sleep(2)
        // In the demo the showcase move happens on this tap; catch the celebration right after it.
        app.descendants(matching: .any)["board"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        for frame in 0..<12 {
            usleep(150_000)
            save("\(language)-1-game-\(String(format: "%02d", frame))")
        }
        app.terminate()
    }

    @MainActor
    private func shootResult(_ language: String) {
        let app = launch(language, extra: ["-demoResult"])
        app.buttons["playButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["resultScore"].waitForExistence(timeout: 10))
        sleep(4)
        save("\(language)-3-result")
        app.terminate()
    }

    @MainActor
    private func shootGift(_ language: String) {
        let app = launch(language, extra: ["-demoGift"])
        XCTAssertTrue(app.buttons["claimDailyReward"].waitForExistence(timeout: 10))
        sleep(2)
        save("\(language)-5-gift")
        app.terminate()
    }

    @MainActor
    private func save(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: folder.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
