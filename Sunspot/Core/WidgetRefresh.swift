import WidgetKit
import Foundation

/// Asks the home screen to redraw, except when nobody is home.
///
/// Calling `WidgetCenter` from a test process waits on a service that is not running there,
/// and the wait is long: it turned a two-second suite into a five-minute one and looked for
/// all the world like a hang.
enum WidgetRefresh {

    /// True when this process is a test run rather than the app.
    ///
    /// The variable is set by the test runner for both XCTest and Swift Testing, and is the
    /// only signal available before any test code runs.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
    }

    static func reload() {
        guard !isRunningTests else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
