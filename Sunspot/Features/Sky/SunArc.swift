import Foundation
import SolarCore

/// The sun's whole path for one day, as directions in the sky.
///
/// Worked out once per day rather than once per frame. The overlay redraws every time the
/// compass twitches — thirty times a second — and recomputing a hundred and forty solar
/// positions inside that loop would burn the battery for a curve that has not changed.
struct SunArc: Equatable {

    struct Step: Equatable {
        let azimuth: Double
        let elevation: Double
    }

    let steps: [Step]
    /// The day these steps belong to, so the arc can tell when it is out of date.
    let day: Date

    init(spot: Spot, containing moment: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = spot.timeZone
        let startOfDay = calendar.startOfDay(for: moment)
        self.day = startOfDay

        // Every five minutes: fine enough that the curve reads as a curve at arm's length.
        self.steps = stride(from: 0, through: 1440, by: 5).compactMap { minute in
            let instant = startOfDay.addingTimeInterval(Double(minute) * 60)
            let sun = Solar.position(at: instant, coordinate: spot.coordinate)
            // A little below the horizon so the arc runs into the ground rather than
            // stopping in mid-air.
            guard sun.elevation > -3 else { return nil }
            return Step(azimuth: sun.azimuth, elevation: sun.elevation)
        }
    }

    /// True when this arc still describes the moment being looked at.
    func covers(_ moment: Date, in timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.isDate(moment, inSameDayAs: day)
    }
}
