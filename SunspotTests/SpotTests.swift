import Testing
import Foundation
import SolarCore
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
            horizon: HorizonProfile(samples: [.init(azimuth: 180, elevation: 70)]),
            timeZone: Self.utc
        )
        #expect(sunny.sunDay(on: Self.midsummer()).exposure == .fullSun)
        #expect(shaded.sunDay(on: Self.midsummer()).exposure == .fullShade)
    }
}
