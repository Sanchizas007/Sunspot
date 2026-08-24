import Testing
import Foundation
@testable import SolarCore

struct HorizonProfileTests {

    @Test("Open sky obstructs nothing")
    func openSkyIsFlat() {
        for azimuth in stride(from: 0.0, to: 360.0, by: 30) {
            #expect(HorizonProfile.open.obstructionElevation(atAzimuth: azimuth) == 0)
        }
    }

    @Test("A single measurement applies all the way round")
    func singleSampleFillsTheRing() {
        let profile = HorizonProfile(samples: [.init(azimuth: 90, elevation: 12)])
        #expect(profile.obstructionElevation(atAzimuth: 90) == 12)
        #expect(profile.obstructionElevation(atAzimuth: 270) == 12)
    }

    @Test("Heights are interpolated between neighbouring measurements")
    func interpolatesBetweenSamples() {
        let profile = HorizonProfile(samples: [
            .init(azimuth: 0, elevation: 0),
            .init(azimuth: 90, elevation: 30)
        ])
        // Halfway round the eastern gap sits halfway up.
        #expect(abs(profile.obstructionElevation(atAzimuth: 45) - 15) < 0.001)
        #expect(abs(profile.obstructionElevation(atAzimuth: 30) - 10) < 0.001)
    }

    @Test("Interpolation wraps across north")
    func interpolatesAcrossNorth() {
        // A gap that spans 0°: from 350° round to 10°.
        let profile = HorizonProfile(samples: [
            .init(azimuth: 350, elevation: 0),
            .init(azimuth: 10, elevation: 20)
        ])
        #expect(abs(profile.obstructionElevation(atAzimuth: 0) - 10) < 0.001)
        #expect(abs(profile.obstructionElevation(atAzimuth: 355) - 5) < 0.001)
        #expect(abs(profile.obstructionElevation(atAzimuth: 5) - 15) < 0.001)
    }

    @Test("Re-measuring a direction corrects it rather than duplicating it")
    func rerecordingReplaces() {
        var profile = HorizonProfile(samples: [.init(azimuth: 180, elevation: 10)])
        profile.record(azimuth: 180, elevation: 25)
        #expect(profile.samples.count == 1)
        #expect(profile.obstructionElevation(atAzimuth: 180) == 25)
    }

    @Test("Azimuths outside a turn are folded back in")
    func normalisesAzimuth() {
        let profile = HorizonProfile(samples: [
            .init(azimuth: 0, elevation: 0),
            .init(azimuth: 180, elevation: 40)
        ])
        #expect(profile.obstructionElevation(atAzimuth: 360) == profile.obstructionElevation(atAzimuth: 0))
        #expect(abs(profile.obstructionElevation(atAzimuth: -90)
                    - profile.obstructionElevation(atAzimuth: 270)) < 0.001)
    }

    @Test("A sun below the skyline is blocked, above it is not")
    func blocksTheSunBelowTheSkyline() {
        let profile = HorizonProfile(samples: [.init(azimuth: 120, elevation: 20)])
        #expect(profile.blocks(SolarPosition(azimuth: 120, elevation: 15)))
        #expect(!profile.blocks(SolarPosition(azimuth: 120, elevation: 25)))
    }

    @Test("Samples are kept in azimuth order however they arrive")
    func keepsSamplesSorted() {
        let profile = HorizonProfile(samples: [
            .init(azimuth: 300, elevation: 5),
            .init(azimuth: 30, elevation: 5),
            .init(azimuth: 150, elevation: 5)
        ])
        #expect(profile.samples.map(\.azimuth) == [30, 150, 300])
    }
}

/// A traced skyline is the one thing in this app a person spends real effort on. It has to
/// survive being written down and read back exactly.
struct HorizonProfileCodingTests {

    @Test("A profile survives a round trip through storage")
    func roundTripsThroughJSON() throws {
        let original = HorizonProfile(samples: [
            .init(azimuth: 12.5, elevation: 8.25),
            .init(azimuth: 190, elevation: 41.75),
            .init(azimuth: 305.125, elevation: 3)
        ])

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(HorizonProfile.self, from: data)

        #expect(restored == original)
        #expect(restored.samples.count == 3)
        for azimuth in stride(from: 0.0, to: 360.0, by: 7) {
            #expect(abs(restored.obstructionElevation(atAzimuth: azimuth)
                        - original.obstructionElevation(atAzimuth: azimuth)) < 1e-9,
                    "the skyline changed shape at \(azimuth)°")
        }
    }

    @Test("An open sky survives storage as an open sky")
    func openSkyRoundTrips() throws {
        let data = try JSONEncoder().encode(HorizonProfile.open)
        let restored = try JSONDecoder().decode(HorizonProfile.self, from: data)
        #expect(restored == HorizonProfile.open)
        #expect(restored.obstructionElevation(atAzimuth: 123) == 0)
    }

    @Test("Reading a file puts the samples back in order")
    func decodingRepairsOrder() throws {
        // A file written by hand, or by a version that did not sort, must not produce a
        // profile whose interpolation walks backwards.
        let json = """
        {"samples":[{"azimuth":300,"elevation":5},{"azimuth":30,"elevation":10},\
        {"azimuth":150,"elevation":20},{"azimuth":30,"elevation":99}]}
        """
        let restored = try JSONDecoder().decode(HorizonProfile.self, from: Data(json.utf8))

        #expect(restored.samples.map(\.azimuth) == [30, 150, 300], "got \(restored.samples)")
        #expect(restored.samples.count == 3, "the repeated direction should collapse to one")
        #expect(restored.obstructionElevation(atAzimuth: 30) == 99, "the later entry should win")
    }

    @Test("A coordinate survives storage")
    func coordinateRoundTrips() throws {
        let original = GeoCoordinate(latitude: 50.4501, longitude: 30.5234)
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(GeoCoordinate.self, from: data) == original)
    }
}

/// A profile has to be able to say how much of it is measurement and how much is guesswork.
/// It could not, and a single tap on the Sky screen became a wall in every direction that
/// silently removed nearly three hours of sun from the answer.
struct HorizonCoverageTests {

    @Test("Nothing measured is a whole circle of guesswork")
    func openSkyIsAllGap() {
        #expect(HorizonProfile.open.largestGap == 360)
        #expect(HorizonProfile.open.measuredArc == 0)
    }

    @Test("One sample is a whole circle of guesswork, however precise it looks")
    func oneSampleIsNotASkyline() {
        // This is the case that shipped: one point at 272°, and the profile happily
        // reported that height for north, east and south as well.
        let single = HorizonProfile(samples: [.init(azimuth: 272, elevation: 13.9)])
        #expect(single.largestGap == 360)
        #expect(single.measuredArc == 0)
        #expect(!single.hasMeasurement(near: 90), "east was never looked at")
        #expect(single.hasMeasurement(near: 272), "west was")
    }

    @Test("The measured arc is the circle minus the biggest hole in it")
    func measuredArcIsWhatWasWalked() {
        // Ninety degrees of south-facing sky, sampled every thirty degrees.
        let southern = HorizonProfile(samples: [
            .init(azimuth: 135, elevation: 10),
            .init(azimuth: 165, elevation: 20),
            .init(azimuth: 195, elevation: 20),
            .init(azimuth: 225, elevation: 10)
        ])
        #expect(abs(southern.largestGap - 270) < 0.001, "gap was \(southern.largestGap)")
        #expect(abs(southern.measuredArc - 90) < 0.001, "arc was \(southern.measuredArc)")
    }

    @Test("A gap that straddles north is measured as one gap, not two")
    func gapWrapsThroughNorth() {
        let profile = HorizonProfile(samples: [
            .init(azimuth: 10, elevation: 5),
            .init(azimuth: 180, elevation: 5),
            .init(azimuth: 350, elevation: 5)
        ])
        // The holes are 170°, 170° and 20°; the widest is 170.
        #expect(abs(profile.largestGap - 170) < 0.001, "gap was \(profile.largestGap)")
    }

    @Test("A direction is only called measured when something was measured near it")
    func measurementIsLocal() {
        let profile = HorizonProfile(samples: [
            .init(azimuth: 90, elevation: 20),
            .init(azimuth: 180, elevation: 30)
        ])
        #expect(profile.hasMeasurement(near: 90))
        #expect(profile.hasMeasurement(near: 100))
        #expect(!profile.hasMeasurement(near: 135), "the middle of a gap is not measured")
        #expect(!profile.hasMeasurement(near: 300))
    }

    @Test("Nearness is judged the short way round the circle")
    func nearnessWrapsThroughNorth() {
        let profile = HorizonProfile(samples: [
            .init(azimuth: 355, elevation: 10),
            .init(azimuth: 180, elevation: 10)
        ])
        #expect(profile.hasMeasurement(near: 5), "five degrees from 355° is ten degrees away")
        #expect(profile.hasMeasurement(near: 350))
        #expect(!profile.hasMeasurement(near: 60))
    }
}

/// Only the part of the horizon the sun actually crosses is worth anyone's time.
struct SunAzimuthRangeTests {

    @Test("At temperate latitudes the sun never crosses the far north")
    func temperateRangeExcludesTheNorth() throws {
        let kyiv = GeoCoordinate(latitude: 50.4501, longitude: 30.5234)
        let range = try #require(Solar.sunAzimuthRange(
            coordinate: kyiv, year: 2026, timeZone: TimeZone(identifier: "UTC")!
        ))

        // Roughly north-east round through south to north-west: wide, but not the whole circle.
        #expect(range.width > 200 && range.width < 300, "width was \(range.width)")
        #expect(range.start > 20 && range.start < 70, "started at \(range.start)")
    }

    @Test("Inside the Arctic Circle the sun goes all the way round")
    func polarRangeIsTheWholeCircle() throws {
        let tromso = GeoCoordinate(latitude: 69.65, longitude: 18.96)
        let range = try #require(Solar.sunAzimuthRange(
            coordinate: tromso, year: 2026, timeZone: TimeZone(identifier: "UTC")!
        ))
        #expect(range.width > 340, "midnight sun should sweep the lot, got \(range.width)")
    }

    @Test("At the equator the sun crosses nearly the whole circle over a year")
    func equatorialRange() throws {
        // Overhead at the equator the sun passes north of the zenith for half the year and
        // south of it for the other half, so between June and December its bearings take in
        // almost every direction. Somebody there really does have to look all the way round.
        let equator = GeoCoordinate(latitude: 0, longitude: 0)
        let range = try #require(Solar.sunAzimuthRange(
            coordinate: equator, year: 2026, timeZone: TimeZone(identifier: "UTC")!
        ))
        #expect(range.width > 300, "width was \(range.width)")
    }
}
