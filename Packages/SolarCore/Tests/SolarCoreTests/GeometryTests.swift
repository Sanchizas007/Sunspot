import Testing
import Foundation
@testable import SolarCore

struct GeometryTests {

    static let kyiv = GeoCoordinate(latitude: 50.4501, longitude: 30.5234)

    @Test("Going nowhere leaves you where you were")
    func zeroDistanceIsIdentity() {
        let there = Self.kyiv.destination(atAzimuth: 137, distance: 0)
        #expect(there == Self.kyiv)
    }

    @Test("A degree of latitude is about 111 kilometres")
    func northSouthDistanceMatchesTheKnownFigure() {
        let north = Self.kyiv.destination(atAzimuth: 0, distance: 111_195)
        #expect(abs(north.latitude - (Self.kyiv.latitude + 1)) < 0.001,
                "ended at \(north.latitude)")
        #expect(abs(north.longitude - Self.kyiv.longitude) < 0.001,
                "heading due north should not change longitude")
    }

    @Test("Each cardinal direction moves the way it should")
    func cardinalDirections() {
        let distance = 5_000.0
        let north = Self.kyiv.destination(atAzimuth: 0, distance: distance)
        let east = Self.kyiv.destination(atAzimuth: 90, distance: distance)
        let south = Self.kyiv.destination(atAzimuth: 180, distance: distance)
        let west = Self.kyiv.destination(atAzimuth: 270, distance: distance)

        #expect(north.latitude > Self.kyiv.latitude)
        #expect(south.latitude < Self.kyiv.latitude)
        #expect(east.longitude > Self.kyiv.longitude)
        #expect(west.longitude < Self.kyiv.longitude)

        // Due east and due west stay on very nearly the same parallel.
        #expect(abs(east.latitude - Self.kyiv.latitude) < 0.01)
        #expect(abs(west.latitude - Self.kyiv.latitude) < 0.01)
    }

    @Test("Walking out and back returns you to the start")
    func outAndBackIsARoundTrip() {
        for azimuth in stride(from: 0.0, to: 360.0, by: 45) {
            let out = Self.kyiv.destination(atAzimuth: azimuth, distance: 10_000)
            let back = out.destination(atAzimuth: azimuth + 180, distance: 10_000)
            // The reverse bearing of a great circle is not exactly the outbound bearing plus
            // 180°, so allow the small convergence error over ten kilometres.
            #expect(abs(back.latitude - Self.kyiv.latitude) < 0.01,
                    "azimuth \(azimuth) came back to \(back.latitude)")
            #expect(abs(back.longitude - Self.kyiv.longitude) < 0.01,
                    "azimuth \(azimuth) came back to \(back.longitude)")
        }
    }

    @Test("Longitude stays inside −180…180 when crossing the antimeridian")
    func longitudeFoldsAtTheAntimeridian() {
        let fiji = GeoCoordinate(latitude: -17.7, longitude: 179.9)
        let east = fiji.destination(atAzimuth: 90, distance: 50_000)
        #expect(east.longitude >= -180 && east.longitude <= 180,
                "longitude ran off the map at \(east.longitude)")
        #expect(east.longitude < 0, "heading east past 180° should come out negative")
    }

    @Test("Bearings outside a single turn behave like their wrapped equivalent")
    func azimuthIsNormalised() {
        let plain = Self.kyiv.destination(atAzimuth: 45, distance: 8_000)
        let wrapped = Self.kyiv.destination(atAzimuth: 405, distance: 8_000)
        let negative = Self.kyiv.destination(atAzimuth: -315, distance: 8_000)
        #expect(abs(plain.latitude - wrapped.latitude) < 1e-9)
        #expect(abs(plain.latitude - negative.latitude) < 1e-9)
        #expect(abs(plain.longitude - negative.longitude) < 1e-9)
    }

    @Test("The poles do not break the calculation")
    func nearThePoles() {
        let nearPole = GeoCoordinate(latitude: 89.9, longitude: 0)
        let over = nearPole.destination(atAzimuth: 0, distance: 30_000)
        #expect(over.latitude <= 90 && over.latitude >= -90,
                "latitude left the sphere at \(over.latitude)")
        #expect(over.longitude >= -180 && over.longitude <= 180)
    }
}
