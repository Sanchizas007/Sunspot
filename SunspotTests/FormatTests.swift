import Testing
import Foundation
@testable import Sunspot

/// The formatter is the layer between correct numbers and an answer a person can act on,
/// so it is worth pinning: a wrong compass point or a stray "0h" reads as a broken app even
/// when the maths underneath is exact.
struct FormatTests {

    @Test("Durations read the way people say them")
    func durations() {
        #expect(Format.duration(minutes: 0) == "none")
        #expect(Format.duration(minutes: 45) == "45m")
        #expect(Format.duration(minutes: 60) == "1h")
        #expect(Format.duration(minutes: 380) == "6h 20m")
        #expect(Format.duration(minutes: 1440) == "24h")
    }

    @Test("A sun below the horizon is described, not given a negative number")
    func anglesBelowHorizon() {
        #expect(Format.angle(-3) == "below the horizon")
        #expect(Format.angle(0) == "0°")
        #expect(Format.angle(34.4) == "34°")
        #expect(Format.angle(34.6) == "35°")
    }

    @Test("Compass points name the direction before the bearing")
    func compassPoints() {
        #expect(Format.compass(0).hasPrefix("north"))
        #expect(Format.compass(90).hasPrefix("east"))
        #expect(Format.compass(180).hasPrefix("south"))
        #expect(Format.compass(270).hasPrefix("west"))
        #expect(Format.compass(135).hasPrefix("south-east"))
        #expect(Format.compass(315).hasPrefix("north-west"))
    }

    @Test("The compass wraps cleanly through north")
    func compassWrapsThroughNorth() {
        // 350° and 10° are both north, and neither should fall off the end of the table.
        #expect(Format.compass(350).hasPrefix("north"))
        #expect(Format.compass(10).hasPrefix("north"))
        #expect(Format.compass(359).hasPrefix("north"))
    }

    @Test("A missing time shows a dash rather than a wrong one")
    func missingTime() {
        #expect(Format.time(nil, in: TimeZone(identifier: "UTC")!) == "—")
    }
}

/// The compass warning is the app's answer to the loudest complaint about the market leader,
/// so its thresholds are worth pinning.
struct CompassTrustTests {

    @Test("Only a well-calibrated compass is treated as usable")
    func usableThreshold() {
        #expect(!MotionTracker.Trust.unavailable.isUsable)
        #expect(!MotionTracker.Trust.uncalibrated.isUsable)
        #expect(!MotionTracker.Trust.low.isUsable)
        #expect(MotionTracker.Trust.medium.isUsable)
        #expect(MotionTracker.Trust.high.isUsable)
    }

    @Test("Every state below the best one explains itself")
    func adviceIsGivenUntilItIsGood() {
        #expect(MotionTracker.Trust.unavailable.advice != nil)
        #expect(MotionTracker.Trust.uncalibrated.advice != nil)
        #expect(MotionTracker.Trust.low.advice != nil)
        #expect(MotionTracker.Trust.medium.advice != nil)
        #expect(MotionTracker.Trust.high.advice == nil, "a good compass should stay quiet")
    }

    @Test("A poor compass is told how to fix itself, not just that it is poor")
    func adviceIsActionable() {
        let advice = MotionTracker.Trust.uncalibrated.advice ?? ""
        #expect(advice.lowercased().contains("figure of eight"),
                "the advice should say what to do: \(advice)")
    }

    @Test("Trust states are ordered from worst to best")
    func trustIsOrdered() {
        #expect(MotionTracker.Trust.unavailable < .uncalibrated)
        #expect(MotionTracker.Trust.uncalibrated < .low)
        #expect(MotionTracker.Trust.low < .medium)
        #expect(MotionTracker.Trust.medium < .high)
    }
}
