import XCTest

/// UI tests that capture screenshots for pull request previews.
///
/// Screenshots are saved as XCTAttachments with `.keepAlways` so Xcode Cloud
/// includes them in the test result bundle. `ci_post_xcodebuild.sh` can then
/// upload them to Imgur (or another host) and embed the URLs in a PR comment.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPullRequestScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui_testing")
        app.launch()

        XCTAssertTrue(app.scrollViews["home_screen"].waitForExistence(timeout: 10))
        attachScreenshot(named: "01-home", in: app)

        app.buttons["settings_button"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        attachScreenshot(named: "02-settings", in: app)

        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        }
    }
}
