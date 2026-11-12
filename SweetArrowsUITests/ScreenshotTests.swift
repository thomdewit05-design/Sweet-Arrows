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

        app.buttons["wheelButton"].tap()
        sleep(2)
        save("\(language)-6-wheel")
        app.swipeDown(velocity: .fast)
        sleep(2)

        app.buttons["prizesButton"].tap()
        sleep(2)
        save("\(language)-4-season")
        let tabs = app.segmentedControls["prizesTabs"].buttons
        if tabs.count >= 3 {
            tabs.element(boundBy: 1).tap()
            sleep(2)
            save("\(language)-5-album")
            tabs.element(boundBy: 2).tap()
            sleep(2)
            save("\(language)-7-tournament")
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        sleep(1)

        play.tap()
        XCTAssertTrue(app.descendants(matching: .any)["score"].waitForExistence(timeout: 10))
        // The showcase move happens 1.5 s after the board appears; catch the celebration at many moments.
        usleep(1_000_000)
        for frame in 0..<12 {
            save("\(language)-1-game-\(String(format: "%02d", frame))")
            usleep(100_000)
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

    private func save(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: folder.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
