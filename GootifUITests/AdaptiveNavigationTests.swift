import XCTest
import UIKit

@MainActor
final class AdaptiveNavigationTests: XCTestCase {
    func testSelectionSurvivesRotationAndCanBeReopened() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }

        let row = app.buttons["notification-layout-preview-report"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let summary = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "A readable report should adapt")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(summary.waitForExistence(timeout: 5))

        // Duo is a phone with either a compact or an expanded navigation layout.
        // Exercise the presentation that is actually visible, not its device idiom.
        if !row.isHittable {
            let sideBack = app.buttons["BackButton"]
            let back = sideBack.exists ? sideBack : app.navigationBars.buttons["Recent"]
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            back.tap()
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(row.isHittable)
            app.buttons["notification-layout-preview-alert"].tap()
            XCTAssertTrue(app.staticTexts["The scheduled backup completed successfully."].waitForExistence(timeout: 5))
            row.tap()
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
        }
    }

}

@MainActor
final class ReadingContinuityTests: XCTestCase {
    func testReadingAndDraftThroughRotation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview", "-longReport", "-openLatestReport"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        let marker = app.staticTexts["Reading checkpoint 6"]
        for _ in 0..<20 {
            if marker.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(marker.isHittable)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(marker.waitForExistence(timeout: 5))
        XCTAssertTrue(marker.isHittable, "Keep the reading section visible after reflow")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(marker.isHittable)

        app.buttons["Settings"].firstMatch.tap()
        let draft = app.descendants(matching: .any)["settings-key-draft"].firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5))
        draft.tap()
        draft.typeText("layout-draft-do-not-save")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue((draft.value as? String)?.contains("layout-draft-do-not-save") == true)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue((draft.value as? String)?.contains("layout-draft-do-not-save") == true)
    }
}

@MainActor
final class FilterAndPagingTests: XCTestCase {
    func testServiceFilterNarrowsTheList() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview"]
        app.launch()
        let report = app.buttons["notification-layout-preview-report"]
        let alert = app.buttons["notification-layout-preview-alert"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))

        app.buttons["filter-premarket-brief"].tap()
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        XCTAssertFalse(alert.exists)

        app.buttons["filter-all"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
    }

    func testPagerStepsThroughTheVisibleList() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview"]
        app.launch()
        let row = app.buttons["notification-layout-preview-report"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let summary = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "A readable report should adapt")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))

        let next = app.buttons["pager-next"]
        let previous = app.buttons["pager-previous"]
        XCTAssertFalse(previous.isEnabled)
        next.tap()
        XCTAssertTrue(app.descendants(matching: .any)["detail-open-link"].firstMatch.waitForExistence(timeout: 5))
        previous.tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
    }
}

/// Opt-in Device Hub review. Create Documents/enable-fold-review in the runner
/// container, then change pose and create the requested acknowledgement file.
@MainActor
final class FoldContinuityTests: XCTestCase {
    func testReadingAndDraftAcrossPoses() throws {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try XCTSkipUnless(FileManager.default.fileExists(atPath: directory.appendingPathComponent("enable-fold-review").path))
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview", "-longReport", "-openLatestReport"]
        app.launch()
        let marker = app.staticTexts["Reading checkpoint 6"]
        for _ in 0..<20 {
            if marker.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(marker.isHittable)
        // Track the first readable heading, rather than a heading at the bottom
        // that can legitimately move below the viewport when text reflows.
        let visible = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Reading checkpoint ")).allElementsBoundByIndex
            .filter { $0.isHittable && $0.frame.minY > app.frame.minY + 80 }
            .sorted { $0.frame.minY < $1.frame.minY }
        let readingLabel = try XCTUnwrap(visible.first).label
        let readingMarker = app.staticTexts[readingLabel]
        for pose in ["open", "partial", "closed"] {
            try awaitPose("reading-" + pose, directory: directory)
            XCTAssertTrue(readingMarker.exists && app.frame.intersects(readingMarker.frame), "Reading section \(readingLabel) remains on screen in \(pose)")
        }
        app.buttons["Settings"].firstMatch.tap()
        let draft = app.descendants(matching: .any)["settings-key-draft"].firstMatch
        draft.tap()
        draft.typeText("fold-draft-do-not-save")
        for pose in ["open", "partial", "closed"] {
            try awaitPose("draft-" + pose, directory: directory)
            XCTAssertTrue((draft.value as? String)?.contains("fold-draft-do-not-save") == true)
        }
    }

    private func awaitPose(_ phase: String, directory: URL) throws {
        let acknowledgement = directory.appendingPathComponent(phase)
        try? FileManager.default.removeItem(at: acknowledgement)
        try phase.write(to: directory.appendingPathComponent("requested-pose"), atomically: true, encoding: .utf8)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: acknowledgement.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 180), .completed)
    }
}

@MainActor
final class WindowResizingTests: XCTestCase {
    func testIPadNarrowWindowKeepsSelectedReport() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview", "-openLatestReport"]
        app.launch()
        let summary = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "A readable report should adapt")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let initialWidth = app.frame.width
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.99))
            .press(forDuration: 1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.7)))
        XCTAssertLessThan(app.frame.width, initialWidth)
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pager-more"].exists)
    }
}

@MainActor
final class OpenLinkTests: XCTestCase {
    private var safari: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.mobilesafari") }

    override func setUp() async throws {
        continueAfterFailure = false
        safari.terminate()
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview"]
        app.launch()
        return app
    }

    func testPushTapOpensBrowserFromColdLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview", "-simulatePushTap"]
        app.launch()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))

        // Coming back shows the notification rather than an empty list.
        app.activate()
        XCTAssertTrue(app.descendants(matching: .any)["detail-open-link"].firstMatch.waitForExistence(timeout: 10))
    }

    // The fixture ID does not exist on the server, so these never get a fetched message.
    func testLinkInPushOpensBrowserWithoutFetchingAndShowsNoError() {
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview", "-simulatePushLink", "https://www.apple.com/shop/buy-iphone"]
        app.launch()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))

        app.activate()
        XCTAssertFalse(app.alerts["Could not open notification"].waitForExistence(timeout: 5))
    }

    func testNonWebLinkInPushIsIgnored() {
        let app = XCUIApplication()
        app.launchArguments = ["-layoutPreview", "-simulatePushLink", "javascript:alert(1)"]
        app.launch()
        XCTAssertTrue(app.alerts["Could not open notification"].waitForExistence(timeout: 20))
        XCTAssertFalse(safari.state == .runningForeground)
    }

    func testRowButtonOpensBrowserOnFirstTap() {
        let app = launchApp()
        let button = app.descendants(matching: .any)["row-open-link"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
    }

    func testDetailButtonOpensBrowserOnFirstTap() {
        let app = launchApp()
        let row = app.descendants(matching: .any)["notification-layout-preview-link"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let button = app.descendants(matching: .any)["detail-open-link"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
    }
}
