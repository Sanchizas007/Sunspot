import Testing
import Foundation
import SolarCore
@testable import Sunspot

struct SunArcTests {

    static let utc = TimeZone(identifier: "UTC")!

    static func spot(latitude: Double = 50.4501, longitude: Double = 30.5234) -> Spot {
        Spot(name: "Test",
             coordinate: GeoCoordinate(latitude: latitude, longitude: longitude),
             timeZone: utc)
    }

    static func moment(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test("An arc knows which day it belongs to")
    func arcKnowsItsDay() {
        let arc = SunArc(spot: Self.spot(), containing: Self.moment(2026, 6, 21, 12))

        #expect(arc.covers(Self.moment(2026, 6, 21, 3), in: Self.utc))
        #expect(arc.covers(Self.moment(2026, 6, 21, 23), in: Self.utc))
        #expect(!arc.covers(Self.moment(2026, 6, 22, 12), in: Self.utc),
                "an arc from yesterday must not be reused today")
        #expect(!arc.covers(Self.moment(2026, 6, 20, 12), in: Self.utc))
    }

    @Test("The arc rises to a peak and comes down again")
    func arcHasTheShapeOfADay() {
        let arc = SunArc(spot: Self.spot(), containing: Self.moment(2026, 6, 21))
        #expect(arc.steps.count > 100, "got \(arc.steps.count) steps")

        let elevations = arc.steps.map(\.elevation)
        let peak = elevations.max()!
        let peakIndex = elevations.firstIndex(of: peak)!

        #expect(peak > 60, "Kyiv at midsummer should reach past 60°, got \(peak)")
        #expect(peakIndex > 0 && peakIndex < elevations.count - 1,
                "the peak should be in the middle of the day, not at an end")
        #expect(elevations.first! < peak && elevations.last! < peak)
    }

    @Test("Bearings sweep forward through the day rather than jumping about")
    func bearingsAdvance() {
        let arc = SunArc(spot: Self.spot(), containing: Self.moment(2026, 6, 21))
        // Only the daylight part, where the sun is genuinely moving across the sky.
        let daylight = arc.steps.filter { $0.elevation > 5 }
        for (earlier, later) in zip(daylight, daylight.dropFirst()) {
            let step = later.azimuth - earlier.azimuth
            #expect(step > 0 && step < 10,
                    "bearing jumped from \(earlier.azimuth) to \(later.azimuth)")
        }
    }

    @Test("Polar night produces no arc at all rather than a broken one")
    func polarNightIsEmpty() {
        // Svalbard in December: the sun never comes near the horizon.
        let svalbard = Self.spot(latitude: 78.22, longitude: 15.65)
        let arc = SunArc(spot: svalbard, containing: Self.moment(2026, 12, 21))
        #expect(arc.steps.isEmpty, "got \(arc.steps.count) steps in polar night")
    }

    @Test("Midnight sun produces an arc that never touches the ground")
    func midnightSunNeverSets() {
        let svalbard = Self.spot(latitude: 78.22, longitude: 15.65)
        let arc = SunArc(spot: svalbard, containing: Self.moment(2026, 6, 21))
        #expect(arc.steps.count > 200, "got \(arc.steps.count) steps")
        #expect(arc.steps.allSatisfy { $0.elevation > 0 },
                "the sun should stay up all day at midsummer this far north")
    }

    @Test("Every direction in an arc is a real bearing and a real height")
    func arcValuesAreSane() {
        for (month, day) in [(3, 20), (6, 21), (9, 22), (12, 21)] {
            let arc = SunArc(spot: Self.spot(), containing: Self.moment(2026, month, day))
            for step in arc.steps {
                #expect(step.azimuth >= 0 && step.azimuth < 360, "bearing \(step.azimuth)")
                #expect(step.elevation > -3.001 && step.elevation <= 90, "height \(step.elevation)")
            }
        }
    }
}
