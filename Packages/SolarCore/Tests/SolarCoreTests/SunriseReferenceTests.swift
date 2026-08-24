import Testing
import Foundation
@testable import SolarCore

/// Sunrise and sunset pinned against outside sources.
///
/// The physics tests elsewhere prove the engine is self-consistent; these prove it agrees
/// with the world. The figures were checked on 2026-08-24 against two independent
/// providers. Where they disagreed with each other — sunrise-sunset.org runs about two
/// minutes wide of Open-Meteo — this engine landed on Open-Meteo, and a separate check
/// confirmed why: at the moments sunrise-sunset.org calls sunrise, the sun's centre is
/// near −1.08°, not the −0.833° its own documentation specifies.
///
/// Tolerance is three minutes. That covers the spread between providers and the fact that
/// Open-Meteo snaps coordinates to a weather grid a few kilometres wide.
struct SunriseReferenceTests {

    struct Reference {
        let name: String
        let coordinate: GeoCoordinate
        let timeZone: String
        let day: DateComponents
        let sunrise: String  // UTC
        let sunset: String   // UTC
    }

    static let references: [Reference] = [
        Reference(
            name: "Kyiv, midsummer",
            coordinate: GeoCoordinate(latitude: 50.4501, longitude: 30.5234),
            timeZone: "Europe/Kyiv",
            day: DateComponents(year: 2026, month: 6, day: 21),
            sunrise: "2026-06-21T01:46:00Z", sunset: "2026-06-21T18:13:00Z"
        ),
        Reference(
            name: "Reykjavík, spring equinox",
            coordinate: GeoCoordinate(latitude: 64.1466, longitude: -21.9426),
            timeZone: "Atlantic/Reykjavik",
            day: DateComponents(year: 2026, month: 3, day: 20),
            sunrise: "2026-03-20T07:27:00Z", sunset: "2026-03-20T19:42:00Z"
        )
    ]

    @Test("Sunrise and sunset land within three minutes of published times",
          arguments: references)
    func matchesPublishedTimes(_ reference: Reference) throws {
        let zone = try #require(TimeZone(identifier: reference.timeZone))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        var components = reference.day
        components.hour = 12
        let noon = try #require(calendar.date(from: components))

        let result = Solar.sunDay(containing: noon, coordinate: reference.coordinate, timeZone: zone)

        let formatter = ISO8601DateFormatter()
        let expectedSunrise = try #require(formatter.date(from: reference.sunrise))
        let expectedSunset = try #require(formatter.date(from: reference.sunset))

        let firstSun = try #require(result.firstSun)
        let lastSun = try #require(result.lastSun)

        let sunriseDrift = firstSun.timeIntervalSince(expectedSunrise) / 60
        let sunsetDrift = lastSun.timeIntervalSince(expectedSunset) / 60

        #expect(abs(sunriseDrift) < 3,
                "\(reference.name): sunrise was \(String(format: "%+.1f", sunriseDrift)) min out")
        #expect(abs(sunsetDrift) < 3,
                "\(reference.name): sunset was \(String(format: "%+.1f", sunsetDrift)) min out")
    }

    @Test("Sunrise happens when the sun's centre is 0.833° below the horizon")
    func sunriseUsesTheStandardThreshold() throws {
        // The figure every almanac publishes: 34 arcminutes of refraction plus the disc's
        // own 16-arcminute radius. If this drifts, every sun-hours total drifts with it.
        let kyiv = GeoCoordinate(latitude: 50.4501, longitude: 30.5234)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Kyiv"))
        let noon = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12)))

        let result = Solar.sunDay(containing: noon, coordinate: kyiv, timeZone: calendar.timeZone)
        let atSunrise = Solar.position(at: try #require(result.firstSun), coordinate: kyiv)

        #expect(abs(atSunrise.elevation + 0.8333) < 0.02,
                "the sun sat at \(atSunrise.elevation)° when the day was declared to start")
    }
}

extension SunriseReferenceTests.Reference: CustomTestStringConvertible {
    var testDescription: String { name }
}
