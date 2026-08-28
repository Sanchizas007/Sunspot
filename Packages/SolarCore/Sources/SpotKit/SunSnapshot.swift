import Foundation
import SolarCore

/// What the home screen should be showing, worked out from what is saved.
///
/// This lives here rather than inside the widget so it can be tested at all. A widget
/// extension has no test target of its own, and the decisions it makes are not trivial: which
/// spot of several, what to say when none has been traced, and what to show somebody who has
/// not paid. Left in the extension, all three would only ever be checked by looking at a home
/// screen and hoping.
public enum SunSnapshot {

    public enum State: Equatable {
        /// Nothing saved yet, or everything deleted.
        case noSpot
        /// The widget is part of the purchase, and it has not been made.
        case locked
        case reading(Reading)
    }

    public struct Reading: Equatable {
        public let name: String
        public let directMinutes: Int
        public let exposure: SunExposure
        public let firstSun: Date?
        public let lastSun: Date?
        public let timeZone: TimeZone
        /// False while the figure still describes open sky rather than a traced skyline.
        public let measured: Bool

        public init(
            name: String, directMinutes: Int, exposure: SunExposure,
            firstSun: Date?, lastSun: Date?, timeZone: TimeZone, measured: Bool
        ) {
            self.name = name
            self.directMinutes = directMinutes
            self.exposure = exposure
            self.firstSun = firstSun
            self.lastSun = lastSun
            self.timeZone = timeZone
            self.measured = measured
        }
    }

    /// Decides what the widget shows.
    ///
    /// The order matters. Having nothing saved is reported before the lock, because telling
    /// somebody to buy a widget that would have nothing to put in it is no use to them.
    public static func state(
        spots: [Spot],
        selectedID: UUID?,
        isUnlocked: Bool,
        at date: Date
    ) -> State {
        guard let spot = spot(from: spots, selectedID: selectedID) else { return .noSpot }
        guard isUnlocked else { return .locked }

        let day = spot.sunDay(on: date)
        return .reading(Reading(
            name: spot.name,
            directMinutes: day.directMinutes,
            exposure: day.exposure,
            firstSun: day.firstSun,
            lastSun: day.lastSun,
            timeZone: spot.timeZone,
            measured: spot.hasMeasuredSkyline
        ))
    }

    /// Which spot to report on.
    ///
    /// Falls back to the first rather than to nothing: a selection can outlive the spot it
    /// pointed at, and an empty home screen is a worse answer than a slightly stale one.
    public static func spot(from spots: [Spot], selectedID: UUID?) -> Spot? {
        guard let selectedID else { return spots.first }
        return spots.first { $0.id == selectedID } ?? spots.first
    }
}
