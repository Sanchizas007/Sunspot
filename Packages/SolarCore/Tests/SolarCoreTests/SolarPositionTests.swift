import Testing
import Foundation
@testable import SolarCore

/// The sun engine is checked against physics rather than against itself: quantities whose
/// values are fixed by the geometry of the solar system, not by any particular
/// implementation of it. A formula that is subtly wrong fails these.
struct SolarPositionTests {

    static let utc = TimeZone(identifier: "UTC")!

    static func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0,
                     zone: TimeZone = utc) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    /// Scans a day for the moment the sun is highest, and returns that position.
    static func solarNoon(on day: Date, at coordinate: GeoCoordinate) -> (Date, SolarPosition) {
        var best = (day, Solar.position(at: day, coordinate: coordinate))
        var cursor = day.addingTimeInterval(-12 * 3600)
        let end = day.addingTimeInterval(12 * 3600)
        while cursor < end {
            let position = Solar.position(at: cursor, coordinate: coordinate)
            if position.elevation > best.1.elevation { best = (cursor, position) }
            cursor.addTimeInterval(30)
        }
        return best
    }

    // MARK: - The tilt of the Earth

    @Test("Declination reaches the axial tilt at the solstices")
    func declinationAtSolstices() {
        // The Earth's axis leans 23.44°, so the sun's declination peaks there and nowhere else.
        let june = Solar.declination(at: Self.date(2026, 6, 21))
        let december = Solar.declination(at: Self.date(2026, 12, 21))

        #expect(abs(june - 23.44) < 0.1, "June solstice declination was \(june)")
        #expect(abs(december + 23.44) < 0.1, "December solstice declination was \(december)")
    }

    @Test("Declination passes through zero at the equinoxes")
    func declinationAtEquinoxes() {
        // The equinox drifts by a day or so year to year, so allow the sun to be within
        // a day's worth of travel — it moves about 0.4° of declination per day in March.
        let march = Solar.declination(at: Self.date(2026, 3, 20))
        let september = Solar.declination(at: Self.date(2026, 9, 22))

        #expect(abs(march) < 0.5, "March equinox declination was \(march)")
        #expect(abs(september) < 0.5, "September equinox declination was \(september)")
    }

    @Test("Declination never leaves the tropics")
    func declinationStaysInRange() {
        for dayOffset in stride(from: 0, to: 365, by: 7) {
            let day = Self.date(2026, 1, 1).addingTimeInterval(Double(dayOffset) * 86400)
            let declination = Solar.declination(at: day)
            #expect(abs(declination) <= 23.5, "declination \(declination) on day \(dayOffset)")
        }
    }

    // MARK: - Noon geometry

    @Test("Noon elevation matches 90° minus the angle from the sun's own latitude")
    func noonElevationFollowsGeometry() {
        // Anywhere on Earth, the sun at its daily peak stands 90° minus the distance
        // between your latitude and the latitude it is overhead.
        let places = [
            GeoCoordinate(latitude: 50.45, longitude: 30.52),   // Kyiv
            GeoCoordinate(latitude: -33.87, longitude: 151.21), // Sydney
            GeoCoordinate(latitude: 0, longitude: 0),           // Gulf of Guinea
            GeoCoordinate(latitude: 64.15, longitude: -21.94)   // Reykjavík
        ]
        for place in places {
            for (month, day) in [(3, 20), (6, 21), (9, 22), (12, 21)] {
                let noonDay = Self.date(2026, month, day)
                let (moment, position) = Self.solarNoon(on: noonDay, at: place)
                let declination = Solar.declination(at: moment)
                let expected = 90 - abs(place.latitude - declination)

                #expect(abs(position.elevation - expected) < 0.3,
                        "lat \(place.latitude) on \(month)/\(day): got \(position.elevation), expected \(expected)")
            }
        }
    }

    @Test("At noon the sun sits due south in the north, and due north in the south")
    func noonAzimuthPointsToThePole() {
        let kyiv = GeoCoordinate(latitude: 50.45, longitude: 30.52)
        let (_, north) = Self.solarNoon(on: Self.date(2026, 6, 21), at: kyiv)
        #expect(abs(north.azimuth - 180) < 0.5, "Kyiv noon azimuth was \(north.azimuth)")

        let sydney = GeoCoordinate(latitude: -33.87, longitude: 151.21)
        let (_, south) = Self.solarNoon(on: Self.date(2026, 6, 21), at: sydney)
        let offsetFromNorth = min(south.azimuth, 360 - south.azimuth)
        #expect(offsetFromNorth < 0.5, "Sydney noon azimuth was \(south.azimuth)")
    }

    @Test("Overhead at the equator on the equinox")
    func equatorEquinoxIsOverhead() {
        let equator = GeoCoordinate(latitude: 0, longitude: 0)
        let (_, position) = Self.solarNoon(on: Self.date(2026, 3, 20), at: equator)
        #expect(position.elevation > 89.4, "elevation was \(position.elevation)")
    }

    // MARK: - The poles

    @Test("Midnight sun above the Arctic Circle, polar night below the Antarctic")
    func polarDayAndNight() {
        let tromso = GeoCoordinate(latitude: 69.65, longitude: 18.96)
        let june = Self.date(2026, 6, 21, 0)

        var lowest = 90.0
        for minute in stride(from: 0, to: 1440, by: 10) {
            let moment = june.addingTimeInterval(Double(minute) * 60)
            lowest = min(lowest, Solar.position(at: moment, coordinate: tromso).elevation)
        }
        #expect(lowest > 0, "the sun dipped to \(lowest)° in Tromsø at midsummer")

        let mcMurdo = GeoCoordinate(latitude: -77.85, longitude: 166.67)
        var highest = -90.0
        for minute in stride(from: 0, to: 1440, by: 10) {
            let moment = june.addingTimeInterval(Double(minute) * 60)
            highest = max(highest, Solar.position(at: moment, coordinate: mcMurdo).elevation)
        }
        #expect(highest < 0, "the sun rose to \(highest)° at McMurdo in polar night")
    }

    // MARK: - Daily motion

    @Test("The sun sweeps clockwise through the northern sky")
    func azimuthAdvancesThroughTheDay() {
        let kyiv = GeoCoordinate(latitude: 50.45, longitude: 30.52)
        // Sample either side of noon: morning in the east, noon south, evening west.
        let morning = Solar.position(at: Self.date(2026, 6, 21, 5), coordinate: kyiv)
        let noon = Solar.position(at: Self.date(2026, 6, 21, 10), coordinate: kyiv)
        let evening = Solar.position(at: Self.date(2026, 6, 21, 16), coordinate: kyiv)

        #expect(morning.azimuth < noon.azimuth)
        #expect(noon.azimuth < evening.azimuth)
        #expect(morning.azimuth > 45 && morning.azimuth < 135, "morning azimuth \(morning.azimuth)")
        #expect(evening.azimuth > 225 && evening.azimuth < 315, "evening azimuth \(evening.azimuth)")
    }

    @Test("Azimuth always lands inside a single turn")
    func azimuthStaysNormalised() {
        let places = [
            GeoCoordinate(latitude: 50.45, longitude: 30.52),
            GeoCoordinate(latitude: -33.87, longitude: 151.21),
            GeoCoordinate(latitude: 0, longitude: -170),
            GeoCoordinate(latitude: 89, longitude: 0)
        ]
        for place in places {
            for hour in 0..<24 {
                let position = Solar.position(at: Self.date(2026, 8, 24, hour), coordinate: place)
                #expect(position.azimuth >= 0 && position.azimuth < 360,
                        "azimuth \(position.azimuth) at lat \(place.latitude) hour \(hour)")
                #expect(position.elevation >= -90 && position.elevation <= 90)
            }
        }
    }

    // MARK: - Clock against sundial

    @Test("The equation of time stays inside its known envelope")
    func equationOfTimeEnvelope() {
        // It swings between roughly −14 and +16 minutes across the year and never further.
        var lowest = 0.0
        var highest = 0.0
        for dayOffset in 0..<365 {
            let day = Self.date(2026, 1, 1).addingTimeInterval(Double(dayOffset) * 86400)
            let value = Solar.equationOfTimeMinutes(at: day)
            lowest = min(lowest, value)
            highest = max(highest, value)
        }
        #expect(lowest < -13 && lowest > -17, "minimum was \(lowest)")
        #expect(highest > 15 && highest < 18, "maximum was \(highest)")
    }

    // MARK: - Refraction

    @Test("Refraction lifts the horizon by about half a degree and fades overhead")
    func refractionBehaves() {
        let atHorizon = Solar.apparentElevation(forGeometric: 0) - 0
        #expect(atHorizon > 0.45 && atHorizon < 0.65, "horizon lift was \(atHorizon)°")

        let overhead = Solar.apparentElevation(forGeometric: 80) - 80
        #expect(overhead >= 0 && overhead < 0.01, "overhead lift was \(overhead)°")
    }

    @Test("Julian Day is anchored at the J2000 epoch")
    func julianDayEpoch() {
        let j2000 = Self.date(2000, 1, 1, 12)
        #expect(abs(Solar.julianDay(j2000) - 2451545.0) < 1e-6)
    }
}
