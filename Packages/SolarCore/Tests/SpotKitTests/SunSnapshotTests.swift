import Testing
import Foundation
import SolarCore
@testable import SpotKit

/// What the home screen shows, which until now was only ever checked by looking at a home
/// screen and hoping. A widget extension has no test target of its own, so the decisions were
/// moved here to be checked properly: which spot of several, what to say when nothing has been
/// traced, and what somebody who has not paid is told.
struct SunSnapshotTests {

    static let zone = TimeZone(identifier: "Europe/Kyiv")!

    static func spot(
        _ name: String,
        horizon: HorizonProfile = .open,
        id: UUID = UUID()
    ) -> Spot {
        Spot(
            id: id,
            name: name,
            coordinate: GeoCoordinate(latitude: 47.8388, longitude: 35.1495),
            horizon: horizon,
            timeZone: zone
        )
    }

    static func noon(_ month: Int = 6, _ day: Int = 21) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    static func traced(elevation: Double) -> HorizonProfile {
        HorizonProfile(samples: stride(from: 0.0, to: 360.0, by: 20)
            .map { .init(azimuth: $0, elevation: elevation) })
    }

    // MARK: - Nothing to show

    @Test("With nothing saved the widget says so rather than showing zero hours")
    func noSpotsMeansNoSpot() {
        let state = SunSnapshot.state(
            spots: [], selectedID: nil, isUnlocked: true, at: Self.noon()
        )
        #expect(state == .noSpot)
    }

    @Test("Having nothing saved is reported before the lock")
    func emptyBeatsLocked() {
        // Telling somebody to buy a widget that would have nothing to put in it is no use.
        let state = SunSnapshot.state(
            spots: [], selectedID: nil, isUnlocked: false, at: Self.noon()
        )
        #expect(state == .noSpot, "an empty widget should not be an advert")
    }

    // MARK: - The lock

    @Test("Without the purchase the widget is locked, not silently blank")
    func unpaidIsLocked() {
        let state = SunSnapshot.state(
            spots: [Self.spot("Back bed")], selectedID: nil, isUnlocked: false, at: Self.noon()
        )
        #expect(state == .locked)
    }

    @Test("With the purchase it reads")
    func paidReads() {
        let state = SunSnapshot.state(
            spots: [Self.spot("Back bed")], selectedID: nil, isUnlocked: true, at: Self.noon()
        )
        guard case .reading = state else {
            Issue.record("expected a reading, got \(state)")
            return
        }
    }

    // MARK: - Which spot

    @Test("The selected spot is the one reported, not simply the first")
    func honoursTheSelection() throws {
        // The failure this guards: somebody with a bed by the fence and a bed by the garage
        // finding the home screen quietly reporting the wrong one.
        let fence = Self.spot("By the fence")
        let garage = Self.spot("By the garage")

        let state = SunSnapshot.state(
            spots: [fence, garage], selectedID: garage.id, isUnlocked: true, at: Self.noon()
        )
        guard case let .reading(reading) = state else {
            Issue.record("expected a reading, got \(state)")
            return
        }
        #expect(reading.name == "By the garage")
    }

    @Test("A selection pointing at a deleted spot falls back rather than going blank")
    func staleSelectionFallsBack() {
        let fence = Self.spot("By the fence")
        let state = SunSnapshot.state(
            spots: [fence], selectedID: UUID(), isUnlocked: true, at: Self.noon()
        )
        guard case let .reading(reading) = state else {
            Issue.record("a stale id emptied the widget instead of falling back")
            return
        }
        #expect(reading.name == "By the fence")
    }

    @Test("With no selection at all the first spot is used")
    func noSelectionUsesTheFirst() {
        let spots = [Self.spot("First"), Self.spot("Second")]
        #expect(SunSnapshot.spot(from: spots, selectedID: nil)?.name == "First")
        #expect(SunSnapshot.spot(from: [], selectedID: nil) == nil)
    }

    // MARK: - What it says

    @Test("The reading carries the spot's own figures, not the device's defaults")
    func readingCarriesTheSpotsFigures() throws {
        let spot = Self.spot("Back bed", horizon: Self.traced(elevation: 20))
        let state = SunSnapshot.state(
            spots: [spot], selectedID: spot.id, isUnlocked: true, at: Self.noon()
        )
        guard case let .reading(reading) = state else {
            Issue.record("expected a reading")
            return
        }

        #expect(reading.timeZone == Self.zone, "a widget in the wrong time zone is wrong all day")
        #expect(reading.measured, "a traced skyline should be reported as measured")
        #expect(reading.directMinutes > 0)
        #expect(reading.firstSun != nil && reading.lastSun != nil)
        #expect(reading.exposure == SunExposure(directMinutes: reading.directMinutes))
    }

    @Test("An untraced spot is flagged, so the home screen never states an upper bound as fact")
    func openSkyIsFlagged() throws {
        let spot = Self.spot("Untraced")
        let state = SunSnapshot.state(
            spots: [spot], selectedID: spot.id, isUnlocked: true, at: Self.noon()
        )
        guard case let .reading(reading) = state else {
            Issue.record("expected a reading")
            return
        }
        #expect(!reading.measured)
    }

    @Test("A spot that gets no sun at all reads as nothing rather than as an error")
    func noSunIsStillAReading() throws {
        let enclosed = Self.spot("Courtyard", horizon: Self.traced(elevation: 85))
        let state = SunSnapshot.state(
            spots: [enclosed], selectedID: enclosed.id, isUnlocked: true, at: Self.noon(12, 21)
        )
        guard case let .reading(reading) = state else {
            Issue.record("a sunless spot should still produce a reading")
            return
        }
        #expect(reading.directMinutes == 0)
        #expect(reading.exposure == .fullShade)
        #expect(reading.firstSun == nil)
    }

    @Test("The figure follows the day it is asked about")
    func readingFollowsTheDate() throws {
        let spot = Self.spot("Back bed")
        func minutes(_ month: Int, _ day: Int) -> Int {
            guard case let .reading(reading) = SunSnapshot.state(
                spots: [spot], selectedID: spot.id, isUnlocked: true, at: Self.noon(month, day)
            ) else { return -1 }
            return reading.directMinutes
        }
        #expect(minutes(6, 21) > minutes(12, 21), "midsummer should beat midwinter")
    }
}
