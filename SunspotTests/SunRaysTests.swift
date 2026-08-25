import Testing
import Foundation
import SolarCore
import SpotKit
@testable import Sunspot

struct SunRaysTests {

    static let utc = TimeZone(identifier: "UTC")!

    static func spot(horizon: HorizonProfile = .open) -> Spot {
        Spot(
            name: "Test",
            coordinate: GeoCoordinate(latitude: 50.4501, longitude: 30.5234),
            horizon: horizon,
            timeZone: utc
        )
    }

    static func moment(hour: Int, minute: Int = 0, month: Int = 6, day: Int = 21) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    @Test("Sunrise comes from the east half of the sky, sunset goes to the west half")
    func raysPointTheRightWay() {
        let rays = SunRays(spot: Self.spot(), at: Self.moment(hour: 10))

        let sunrise = try! #require(rays.sunrise)
        let sunset = try! #require(rays.sunset)

        #expect(sunrise.azimuth > 0 && sunrise.azimuth < 180,
                "sunrise azimuth was \(sunrise.azimuth)")
        #expect(sunset.azimuth > 180 && sunset.azimuth < 360,
                "sunset azimuth was \(sunset.azimuth)")
    }

    @Test("Every ray starts at the spot and runs the intended distance")
    func raysStartAtTheSpotAndAreTheRightLength() {
        let spot = Self.spot()
        let rays = SunRays(spot: spot, at: Self.moment(hour: 10))
        #expect(!rays.all.isEmpty)

        for ray in rays.all {
            #expect(ray.from == spot.coordinate)

            // Rough great-circle distance, enough to confirm the ray is the length asked for.
            let dLat = (ray.to.latitude - ray.from.latitude) * 111_195
            let dLon = (ray.to.longitude - ray.from.longitude) * 111_195
                * cos(ray.from.latitude * .pi / 180)
            let distance = (dLat * dLat + dLon * dLon).squareRoot()
            #expect(abs(distance - SunRays.length) < 50,
                    "\(ray.kind) ray ran \(distance)m instead of \(SunRays.length)m")
        }
    }

    @Test("There is no 'now' ray while the sun is down")
    func noNowRayAtNight() {
        // Midwinter, well before dawn in Kyiv.
        let rays = SunRays(spot: Self.spot(), at: Self.moment(hour: 2, month: 12, day: 21))
        #expect(rays.now == nil)
        // Sunrise and sunset for the day are still known, and still worth drawing.
        #expect(rays.sunrise != nil)
        #expect(rays.sunset != nil)
    }

    @Test("The 'now' ray appears once the sun is up and tracks it across the day")
    func nowRayFollowsTheSun() {
        let spot = Self.spot()
        let morning = SunRays(spot: spot, at: Self.moment(hour: 4))
        let afternoon = SunRays(spot: spot, at: Self.moment(hour: 15))

        let morningRay = try! #require(morning.now)
        let afternoonRay = try! #require(afternoon.now)
        #expect(morningRay.azimuth < afternoonRay.azimuth,
                "the sun should have moved clockwise: \(morningRay.azimuth) then \(afternoonRay.azimuth)")
    }

    @Test("A skyline that blocks the morning moves the sunrise ray later and further round")
    func tracedSkylineChangesTheRays() {
        let open = SunRays(spot: Self.spot(), at: Self.moment(hour: 10))
        let walled = SunRays(
            spot: Self.spot(horizon: HorizonProfile(samples: [
                .init(azimuth: 0, elevation: 0),
                .init(azimuth: 45, elevation: 35),
                .init(azimuth: 135, elevation: 35),
                .init(azimuth: 180, elevation: 0)
            ])),
            at: Self.moment(hour: 10)
        )

        let openSunrise = try! #require(open.sunrise)
        let walledSunrise = try! #require(walled.sunrise)
        // With the east blocked, the first sun a spot sees arrives from further south.
        #expect(walledSunrise.azimuth > openSunrise.azimuth,
                "open \(openSunrise.azimuth), walled \(walledSunrise.azimuth)")
    }
}
