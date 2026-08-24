import Testing
import Foundation
@testable import SolarCore

struct SunHoursTests {

    static let utc = TimeZone(identifier: "UTC")!
    static let kyiv = GeoCoordinate(latitude: 50.45, longitude: 30.52)

    static func day(_ y: Int, _ mo: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: 12))!
    }

    @Test("Under open sky the day is long in June and short in December")
    func openSkyFollowsTheSeason() {
        let june = Solar.sunDay(containing: Self.day(2026, 6, 21), coordinate: Self.kyiv, timeZone: Self.utc)
        let december = Solar.sunDay(containing: Self.day(2026, 12, 21), coordinate: Self.kyiv, timeZone: Self.utc)

        // Kyiv gets roughly 16h20m at midsummer and 8h at midwinter.
        #expect(june.directMinutes > 950 && june.directMinutes < 1000,
                "June gave \(june.directMinutes) minutes")
        #expect(december.directMinutes > 450 && december.directMinutes < 510,
                "December gave \(december.directMinutes) minutes")
        #expect(june.directMinutes > december.directMinutes)
    }

    @Test("The equator gets about twelve hours whatever the month")
    func equatorIsSteady() {
        let equator = GeoCoordinate(latitude: 0, longitude: 0)
        for (month, day) in [(3, 20), (6, 21), (9, 22), (12, 21)] {
            let result = Solar.sunDay(
                containing: Self.day(2026, month, day), coordinate: equator, timeZone: Self.utc
            )
            #expect(abs(result.directMinutes - 720) < 20,
                    "\(month)/\(day) gave \(result.directMinutes) minutes")
        }
    }

    @Test("Open sky yields one unbroken stretch from sunrise to sunset")
    func openSkyIsOneStretch() {
        let result = Solar.sunDay(containing: Self.day(2026, 6, 21), coordinate: Self.kyiv, timeZone: Self.utc)
        #expect(result.intervals.count == 1)
        #expect(result.longestStretchMinutes == result.directMinutes)
        #expect(result.firstSun != nil && result.lastSun != nil)
    }

    @Test("A wall to the east delays the first sun and cuts the total")
    func obstructionCutsTheMorning() {
        let open = Solar.sunDay(containing: Self.day(2026, 6, 21), coordinate: Self.kyiv, timeZone: Self.utc)

        // A tall building filling the eastern sky from north-east round to south-east.
        let walled = HorizonProfile(samples: [
            .init(azimuth: 0, elevation: 0),
            .init(azimuth: 45, elevation: 40),
            .init(azimuth: 135, elevation: 40),
            .init(azimuth: 180, elevation: 0)
        ])
        let shaded = Solar.sunDay(
            containing: Self.day(2026, 6, 21), coordinate: Self.kyiv,
            timeZone: Self.utc, horizon: walled
        )

        #expect(shaded.directMinutes < open.directMinutes)
        #expect(shaded.firstSun! > open.firstSun!, "the wall should hold the morning sun off")
        #expect(abs(shaded.lastSun!.timeIntervalSince(open.lastSun!)) < 120,
                "the western evening should be untouched")
    }

    @Test("A courtyard walled all round gets nothing")
    func fullyEnclosedSpotGetsNoSun() {
        let walls = HorizonProfile(samples: [.init(azimuth: 0, elevation: 89)])
        let result = Solar.sunDay(
            containing: Self.day(2026, 6, 21), coordinate: Self.kyiv,
            timeZone: Self.utc, horizon: walls
        )
        #expect(result.directMinutes == 0)
        #expect(result.intervals.isEmpty)
        #expect(result.firstSun == nil)
        #expect(result.exposure == .fullShade)
    }

    @Test("A tall tree due south splits the day in two")
    func obstructionAtNoonProducesTwoStretches() {
        // A narrow, tall obstruction sitting due south — a cypress, a chimney stack —
        // with open sky to either side of it. The sun clears the roofs in the morning,
        // disappears behind the tree around noon, and comes back out in the afternoon.
        let profile = HorizonProfile(samples: [
            .init(azimuth: 90, elevation: 0),
            .init(azimuth: 160, elevation: 0),
            .init(azimuth: 168, elevation: 60),
            .init(azimuth: 192, elevation: 60),
            .init(azimuth: 200, elevation: 0),
            .init(azimuth: 270, elevation: 0)
        ])
        let result = Solar.sunDay(
            containing: Self.day(2026, 3, 20), coordinate: Self.kyiv,
            timeZone: Self.utc, horizon: profile
        )
        #expect(result.intervals.count == 2,
                "expected morning and afternoon, got \(result.intervals.count) stretch(es)")
        #expect(result.longestStretchMinutes < result.directMinutes,
                "neither stretch should account for the whole day")
        #expect(result.directMinutes > 0)
    }

    @Test("Exposure is graded the way plant labels are worded")
    func exposureThresholdsMatchPlantLabels() {
        #expect(SunExposure(directMinutes: 0) == .fullShade)
        #expect(SunExposure(directMinutes: 119) == .fullShade)
        #expect(SunExposure(directMinutes: 120) == .partShade)
        #expect(SunExposure(directMinutes: 239) == .partShade)
        #expect(SunExposure(directMinutes: 240) == .partSun)
        #expect(SunExposure(directMinutes: 359) == .partSun)
        #expect(SunExposure(directMinutes: 360) == .fullSun)
        #expect(SunExposure(directMinutes: 900) == .fullSun)
    }

    @Test("A year of days peaks at midsummer and bottoms at midwinter")
    func yearFollowsTheSeason() {
        let year = Solar.sunYear(year: 2026, coordinate: Self.kyiv, timeZone: Self.utc)
        #expect(year.count >= 365)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.utc
        let peak = year.max { $0.directMinutes < $1.directMinutes }!
        let trough = year.min { $0.directMinutes < $1.directMinutes }!

        #expect(calendar.component(.month, from: peak.date) == 6, "peak fell in month \(calendar.component(.month, from: peak.date))")
        #expect(calendar.component(.month, from: trough.date) == 12, "trough fell in month \(calendar.component(.month, from: trough.date))")
    }

    @Test("The day is counted in the time zone it is asked for")
    func respectsTheRequestedTimeZone() {
        let sydney = GeoCoordinate(latitude: -33.87, longitude: 151.21)
        let local = TimeZone(identifier: "Australia/Sydney")!
        let result = Solar.sunDay(containing: Self.day(2026, 6, 21), coordinate: sydney, timeZone: local)

        // A southern midwinter day, and it must be a single unbroken stretch under open sky.
        #expect(result.intervals.count == 1, "got \(result.intervals.count) stretches")
        #expect(result.directMinutes > 500 && result.directMinutes < 620,
                "Sydney midwinter gave \(result.directMinutes) minutes")
    }
}
