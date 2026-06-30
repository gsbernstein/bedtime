import XCTest

extension XCTestCase {
    func attachScreenshot(named name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
