import WidgetKit
import Foundation
import SolarCore
import SpotKit

/// One reading of the spot, for one moment.
struct TodaySunEntry: TimelineEntry {
    let date: Date
    let state: State

    enum State {
        /// Nothing traced yet, or no spot saved.
        case noSpot
        /// Bought, with a spot to report on.
        case reading(Reading)
        /// The year and the widget are behind the purchase.
        case locked
    }

    struct Reading {
        let name: String
        let directMinutes: Int
        let exposure: SunExposure
        let firstSun: Date?
        let lastSun: Date?
        let timeZone: TimeZone
        /// False while the answer is still an open-sky upper bound.
        let measured: Bool
    }

    static func placeholder(at date: Date = .now) -> TodaySunEntry {
        TodaySunEntry(date: date, state: .reading(Reading(
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
