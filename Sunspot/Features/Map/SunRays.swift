import Foundation
import SpotKit
import SolarCore

/// The lines drawn from a spot to show where the sun comes from and goes.
///
/// A map of the sun is not a chart of angles — it is three lines on the ground that a
/// person can stand on and look along.
struct SunRays {

    struct Ray: Identifiable {
        enum Kind: String { case sunrise, sunset, now }
        var id: String { kind.rawValue }
        let kind: Kind
        let from: GeoCoordinate
        let to: GeoCoordinate
        let azimuth: Double
    }

    /// How far the rays extend on the ground. Long enough to reach past the buildings that
    /// matter at neighbourhood zoom, short enough not to swamp the map.
    static let length: Double = 1_200

    let sunrise: Ray?
    let sunset: Ray?
    let now: Ray?

    var all: [Ray] { [sunrise, sunset, now].compactMap { $0 } }

    init(spot: Spot, at moment: Date) {
        let day = spot.sunDay(on: moment)

        func ray(_ kind: Ray.Kind, at date: Date?) -> Ray? {
            guard let date else { return nil }
            let azimuth = spot.sunPosition(at: date).azimuth
            return Ray(
                kind: kind,
                from: spot.coordinate,
                to: spot.coordinate.destination(atAzimuth: azimuth, distance: Self.length),
                azimuth: azimuth
            )
        }

        sunrise = ray(.sunrise, at: day.firstSun)
        sunset = ray(.sunset, at: day.lastSun)

        // The "now" ray only means something while the sun is actually up.
        let current = spot.sunPosition(at: moment)
        now = current.elevation > 0 ? ray(.now, at: moment) : nil
    }
}
