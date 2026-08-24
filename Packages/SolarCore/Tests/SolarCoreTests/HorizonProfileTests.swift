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
