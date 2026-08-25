import Testing
import Foundation
import SolarCore
import SpotKit
@testable import Sunspot

struct SpotTests {

    static let kyiv = GeoCoordinate(latitude: 50.4501, longitude: 30.5234)
    static let utc = TimeZone(identifier: "UTC")!

    static func midsummer() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!
    }

    @Test("A fresh spot reports open sky and says so")
    func freshSpotIsOpenSky() {
        let spot = Spot(name: "Here", coordinate: Self.kyiv, timeZone: Self.utc)
        #expect(!spot.hasMeasuredSkyline)
        #expect(spot.sunDay(on: Self.midsummer()).directMinutes > 900)
    }

    @Test("Tracing a skyline cuts the figure and flips the flag")
    func tracedSkylineChangesTheAnswer() {
        let open = Spot(name: "Here", coordinate: Self.kyiv, timeZone: Self.utc)
        let walled = Spot(
            name: "Here",
            coordinate: Self.kyiv,
            horizon: HorizonProfile(samples: [
                .init(azimuth: 45, elevation: 35),
                .init(azimuth: 135, elevation: 35),
                .init(azimuth: 180, elevation: 0),
                .init(azimuth: 315, elevation: 0)
            ]),
            timeZone: Self.utc
        )

        #expect(walled.hasMeasuredSkyline)
        #expect(walled.sunDay(on: Self.midsummer()).directMinutes
                < open.sunDay(on: Self.midsummer()).directMinutes)
    }

    @Test("Two spots at the same place with different skylines disagree")
    func skylineIsWhatDistinguishesSpots() {
        // The whole premise of the app: the coordinate is not the answer.
        let sunny = Spot(name: "Bed by the fence", coordinate: Self.kyiv, timeZone: Self.utc)
        let shaded = Spot(
            name: "Bed by the garage",
            coordinate: Self.kyiv,
            // A real trace: walked right round, not a single tap.
            horizon: HorizonProfile(samples: stride(from: 0.0, to: 360.0, by: 20)
                .map { .init(azimuth: $0, elevation: 75) }),
            timeZone: Self.utc
        )
        #expect(sunny.sunDay(on: Self.midsummer()).exposure == .fullSun)
        #expect(shaded.sunDay(on: Self.midsummer()).exposure == .fullShade)
    }
}

/// A skyline thin enough to be meaningless must not be treated as one.
///
/// This is a regression from a real session: a single tap on the Sky screen saved one point
/// at 272°, the profile reported that height for every direction, and the answer quietly
/// lost a hundred and sixty-nine minutes of sun — presented with no caveat at all.
struct ThinTraceTests {

    static let zaporizhzhia = GeoCoordinate(latitude: 47.8388, longitude: 35.1495)
    static let zone = TimeZone(identifier: "Europe/Kyiv")!

    static func day() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: 24, hour: 12))!
    }

    static func spot(_ horizon: HorizonProfile) -> Spot {
        Spot(name: "Here", coordinate: zaporizhzhia, horizon: horizon, timeZone: zone)
    }

    @Test("A single tap is not a skyline and does not change the answer")
    func singleSampleIsIgnored() {
        let tapped = Self.spot(HorizonProfile(samples: [
            .init(azimuth: 272.0025, elevation: 13.920153167795833)
        ]))
        let openSky = Self.spot(.open)

        #expect(!tapped.hasMeasuredSkyline, "one point must not count as measured")
        #expect(tapped.sunDay(on: Self.day()).directMinutes
                == openSky.sunDay(on: Self.day()).directMinutes,
                "a single tap changed the answer")
    }

    @Test("A sweep too narrow to mean anything is also set aside")
    func narrowSweepIsIgnored() {
        // Ten degrees of horizon says nothing about the rest of the sky.
        let narrow = Self.spot(HorizonProfile(samples: [
            .init(azimuth: 180, elevation: 30),
            .init(azimuth: 185, elevation: 31),
            .init(azimuth: 190, elevation: 30)
        ]))
        #expect(narrow.measuredArc < Spot.minimumUsefulArc)
        #expect(!narrow.hasMeasuredSkyline)
        #expect(narrow.sunDay(on: Self.day()).directMinutes
                == Self.spot(.open).sunDay(on: Self.day()).directMinutes)
    }

    @Test("A proper sweep counts, and does change the answer")
    func realTraceIsUsed() {
        let traced = Self.spot(HorizonProfile(samples: stride(from: 90.0, through: 270.0, by: 15)
            .map { .init(azimuth: $0, elevation: 30) }))

        #expect(traced.hasMeasuredSkyline)
        #expect(traced.measuredArc >= Spot.minimumUsefulArc)
        #expect(traced.sunDay(on: Self.day()).directMinutes
                < Self.spot(.open).sunDay(on: Self.day()).directMinutes,
                "a real skyline should take sun away")
    }

    @Test("A trace that is set aside is not quietly deleted")
    func thinTraceIsKeptButUnused() {
        // The person can carry on from what they drew rather than starting again.
        let tapped = Self.spot(HorizonProfile(samples: [.init(azimuth: 272, elevation: 14)]))
        #expect(tapped.horizon.samples.count == 1, "the drawing is still there")
        #expect(tapped.effectiveHorizon == .open, "but it is not used")
    }

    @Test("The sun's own arc is what a trace should be measured against")
    func sunArcIsKnown() throws {
        let width = try #require(Self.spot(.open).sunArcWidth(in: 2026))
        #expect(width > 200 && width < 300, "got \(width)°")
    }
}
