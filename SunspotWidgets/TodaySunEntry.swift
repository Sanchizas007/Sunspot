import WidgetKit
import Foundation
import SolarCore
import SpotKit

/// One reading of the spot, for one moment.
///
/// A thin wrapper: what to show is decided by `SunSnapshot` in the shared module, where it
/// can be tested without a home screen.
struct TodaySunEntry: TimelineEntry {
    let date: Date
    let state: SunSnapshot.State

    static func placeholder(at date: Date = .now) -> TodaySunEntry {
        TodaySunEntry(date: date, state: .reading(SunSnapshot.Reading(
            name: "Here",
            directMinutes: 382,
            exposure: .fullSun,
            firstSun: date.addingTimeInterval(-4 * 3600),
            lastSun: date.addingTimeInterval(5 * 3600),
            timeZone: .current,
            measured: true
        )))
    }
}
