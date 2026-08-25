import Testing
import Foundation
import SolarCore
import SpotKit
@testable import Sunspot

/// The year screen turns a curve into a sentence someone repeats to a neighbour. If the
/// window logic is a fortnight out, the sentence is wrong and nothing on screen looks it.
struct SunYearTests {

    static let utc = TimeZone(identifier: "UTC")!

    static func date(_ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    /// A year built by hand, so the expected answer is known exactly.
    static func year(_ minutesFor: (Int) -> Int) -> SunYear {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let days = (0..<365).map { offset in
            SunYear.Day(
                date: calendar.date(byAdding: .day, value: offset, to: start)!,
                minutes: minutesFor(offset)
            )
        }
        return SunYear(year: 2026, days: days)
    }

    static func dayOfYear(_ date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.ordinality(of: .day, in: .year, for: date)!
    }

    // MARK: - Seasons

    @Test("A summer window is found with the right ends")
    func summerWindowIsFound() throws {
        // Six hours or more from day 100 to day 250 inclusive, nothing either side.
        let year = Self.year { offset in (100...250).contains(offset) ? 400 : 200 }
        let season = try #require(year.season(atLeast: .fullSun))

        #expect(Self.dayOfYear(season.lowerBound) == 101, "started on day \(Self.dayOfYear(season.lowerBound))")
        #expect(Self.dayOfYear(season.upperBound) == 251, "ended on day \(Self.dayOfYear(season.upperBound))")
    }

    @Test("The longest run wins, not the first one")
    func longestRunWins() throws {
        // Three good days in March, then a real season from day 120 to 240.
        let year = Self.year { offset in
            (60...62).contains(offset) || (120...240).contains(offset) ? 400 : 100
        }
        let season = try #require(year.season(atLeast: .fullSun))

        // A spot that scrapes six hours for three days has not got a growing season.
        #expect(Self.dayOfYear(season.lowerBound) == 121)
        #expect(Self.dayOfYear(season.upperBound) == 241)
    }

    @Test("A window running to the end of the year is not cut short")
    func windowAtYearEndIsClosed() throws {
        let year = Self.year { offset in offset >= 300 ? 400 : 100 }
        let season = try #require(year.season(atLeast: .fullSun))
        #expect(Self.dayOfYear(season.lowerBound) == 301)
        #expect(Self.dayOfYear(season.upperBound) == 365)
    }

    @Test("A spot that never reaches a grade says so rather than inventing a window")
    func neverReachingIsReported() {
        let year = Self.year { _ in 90 }
        #expect(year.season(atLeast: .fullSun) == nil)
        #expect(year.season(atLeast: .partSun) == nil)
        #expect(year.neverReaches(.fullSun))
        #expect(year.season(atLeast: .fullShade) != nil, "everything reaches full shade")
    }

    @Test("Grades nest: anything that is full sun is also part sun")
    func gradesNest() throws {
        let year = Self.year { offset in (150...200).contains(offset) ? 400 : 250 }
        let fullSun = try #require(year.season(atLeast: .fullSun))
        let partSun = try #require(year.season(atLeast: .partSun))

        #expect(partSun.lowerBound <= fullSun.lowerBound)
        #expect(partSun.upperBound >= fullSun.upperBound)
    }

    // MARK: - Blackout

    @Test("A winter with no sun at all is found, and read as one spell")
    func blackoutIsFound() throws {
        // Dark for the first forty days and from day 321 on. That is one winter, not two
        // stubs at either end of a calendar.
        let year = Self.year { offset in (offset < 40 || offset > 320) ? 0 : 300 }
        let blackout = try #require(year.blackout)

        #expect(Self.dayOfYear(blackout.lowerBound) == 322, "started on day \(Self.dayOfYear(blackout.lowerBound))")
        #expect(Self.dayOfYear(blackout.upperBound) == 40, "should run into the next year, ended on day \(Self.dayOfYear(blackout.upperBound))")
        #expect(blackout.upperBound > blackout.lowerBound, "the range must still read forwards")

        let days = blackout.upperBound.timeIntervalSince(blackout.lowerBound) / 86400
        #expect(abs(days - 84) < 2, "the whole spell is 84 days, got \(days)")
    }

    @Test("A spot that always sees the sun has no blackout")
    func noBlackoutWhenSunAlwaysReaches() {
        #expect(Self.year { _ in 60 }.blackout == nil)
    }

    @Test("A single dark day still counts as a blackout")
    func singleDarkDayCounts() throws {
        let year = Self.year { offset in offset == 180 ? 0 : 400 }
        let blackout = try #require(year.blackout)
        #expect(Self.dayOfYear(blackout.lowerBound) == 181)
        #expect(blackout.lowerBound == blackout.upperBound)
    }

    // MARK: - Extremes

    @Test("The sunniest and darkest days are the ones they should be")
    func extremesAreFound() throws {
        let year = Self.year { offset in offset == 171 ? 950 : (offset == 354 ? 10 : 400) }
        #expect(Self.dayOfYear(try #require(year.sunniest).date) == 172)
        #expect(Self.dayOfYear(try #require(year.darkest).date) == 355)
    }

    @Test("An empty year answers nothing rather than crashing")
    func emptyYearIsSafe() {
        let empty = SunYear(year: 2026, days: [])
        #expect(empty.sunniest == nil)
        #expect(empty.darkest == nil)
        #expect(empty.blackout == nil)
        #expect(empty.season(atLeast: .fullSun) == nil)
    }

    // MARK: - Against the real engine

    @Test("A real spot peaks at midsummer and bottoms at midwinter")
    func realYearHasTheShapeOfTheSeasons() throws {
        let spot = Spot(
            name: "Test",
            coordinate: GeoCoordinate(latitude: 47.8388, longitude: 35.1495),
            timeZone: Self.utc
        )
        let year = SunYear(spot: spot, year: 2026)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.utc
        #expect(calendar.component(.month, from: try #require(year.sunniest).date) == 6)
        #expect(calendar.component(.month, from: try #require(year.darkest).date) == 12)

        // Open sky at this latitude is full sun for most of the year and never fully dark.
        #expect(year.blackout == nil)
        #expect(year.season(atLeast: .fullSun) != nil)
    }

    @Test("A traced skyline shortens the season and can create a dark winter")
    func skylineChangesTheYear() throws {
        let coordinate = GeoCoordinate(latitude: 47.8388, longitude: 35.1495)
        let open = SunYear(spot: Spot(name: "Open", coordinate: coordinate, timeZone: Self.utc), year: 2026)

        // Walls about as high as the ones measured on a real phone.
        let enclosed = SunYear(
            spot: Spot(
                name: "Enclosed",
                coordinate: coordinate,
                horizon: HorizonProfile(samples: stride(from: 0.0, to: 360.0, by: 10)
                    .map { .init(azimuth: $0, elevation: 27) }),
                timeZone: Self.utc
            ),
            year: 2026
        )

        let openSeason = try #require(open.season(atLeast: .fullSun))
        let enclosedSeason = enclosed.season(atLeast: .fullSun)

        if let enclosedSeason {
            let openLength = openSeason.upperBound.timeIntervalSince(openSeason.lowerBound)
            let enclosedLength = enclosedSeason.upperBound.timeIntervalSince(enclosedSeason.lowerBound)
            #expect(enclosedLength < openLength, "walls should shorten the season")
        }
        #expect(enclosed.blackout != nil, "a 27° wall all round should black out midwinter")
    }
}

/// A season does not care where January is. A southern summer runs from November into
/// February, and a northern dark spell from December into January; reporting either as
/// ending on the thirty-first of December is an artefact of the calendar.
struct SunYearWrapTests {

    static let utc = TimeZone(identifier: "UTC")!

    static func year(_ minutesFor: (Int) -> Int) -> SunYear {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        return SunYear(year: 2026, days: (0..<365).map { offset in
            SunYear.Day(date: calendar.date(byAdding: .day, value: offset, to: start)!,
                        minutes: minutesFor(offset))
        })
    }

    static func monthDay(_ date: Date) -> (Int, Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return (calendar.component(.month, from: date), calendar.component(.day, from: date))
    }

    @Test("A dark winter is reported from December into January, not cut at the year's end")
    func blackoutJoinsAcrossTheNewYear() throws {
        // Dark for the first 20 days and the last 25: one 45-day spell, not two.
        let year = Self.year { offset in (offset < 20 || offset >= 340) ? 0 : 400 }
        let blackout = try #require(year.blackout)

        let (startMonth, _) = Self.monthDay(blackout.lowerBound)
        let (endMonth, _) = Self.monthDay(blackout.upperBound)
        #expect(startMonth == 12, "should start in December, started in month \(startMonth)")
        #expect(endMonth == 1, "should end in January, ended in month \(endMonth)")
        #expect(blackout.upperBound > blackout.lowerBound, "the range must read forwards")

        let days = blackout.upperBound.timeIntervalSince(blackout.lowerBound) / 86400
        #expect(abs(days - 44) < 2, "spell came out \(days) days long")
    }

    @Test("A southern summer is one season, not two halves of a calendar")
    func southernSummerJoins() throws {
        // Full sun from November through February.
        let year = Self.year { offset in (offset < 59 || offset >= 305) ? 400 : 100 }
        let season = try #require(year.season(atLeast: .fullSun))

        #expect(Self.monthDay(season.lowerBound).0 == 11, "started in month \(Self.monthDay(season.lowerBound).0)")
        #expect(Self.monthDay(season.upperBound).0 == 2, "ended in month \(Self.monthDay(season.upperBound).0)")
    }

    @Test("A longer run inside the year still beats a short wrapped one")
    func plainRunCanStillWin() throws {
        // Five days either side of the new year, and a real season from day 100 to 250.
        let year = Self.year { offset in
            (offset < 5 || offset >= 360 || (100...250).contains(offset)) ? 400 : 100
        }
        let season = try #require(year.season(atLeast: .fullSun))
        #expect(Self.monthDay(season.lowerBound).0 == 4, "should be the spring season, got month \(Self.monthDay(season.lowerBound).0)")
    }

    @Test("A year that never breaks is reported as the whole year")
    func alwaysSunnyIsTheWholeYear() throws {
        let season = try #require(Self.year { _ in 500 }.season(atLeast: .fullSun))
        let days = season.upperBound.timeIntervalSince(season.lowerBound) / 86400
        #expect(days > 360, "got \(days) days")
        #expect(Format.dateRange(season, in: Self.utc) == "all year")
    }

    @Test("Only touching one end of the year is not a wrap")
    func runAtOneEndOnlyIsNotJoined() throws {
        let year = Self.year { offset in offset >= 300 ? 400 : 100 }
        let season = try #require(year.season(atLeast: .fullSun))
        #expect(Self.monthDay(season.upperBound).0 == 12, "should end in December")
        let days = season.upperBound.timeIntervalSince(season.lowerBound) / 86400
        #expect(abs(days - 64) < 2, "got \(days) days")
    }
}
