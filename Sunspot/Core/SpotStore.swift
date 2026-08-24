import Foundation
import Observation
import SolarCore

/// The one spot the app is talking about, and the moment being examined.
///
/// Both screens read from here so they can never disagree: scrubbing the day on the map
/// moves the sun on every other screen too.
@MainActor
@Observable
final class SpotStore {

    private(set) var spot: Spot?

    /// The moment under examination. Starts at now and follows the clock until the person
    /// scrubs, after which it stays where they put it.
    var viewedDate: Date = .now

    /// True while the app is still following the clock rather than a chosen time.
    private(set) var followsClock = true

    /// Adopts a position from the device, unless the person has already placed a spot by
    /// hand — a location update should not yank the pin out from under them.
    func adoptDeviceLocation(latitude: Double, longitude: Double) {
        guard spot == nil else { return }
        spot = Spot(name: "Here", coordinate: GeoCoordinate(latitude: latitude, longitude: longitude))
    }

    /// Moves the spot, keeping any skyline already traced for it.
    func move(to coordinate: GeoCoordinate) {
        if var existing = spot {
            existing.coordinate = coordinate
            spot = existing
        } else {
            spot = Spot(name: "Spot", coordinate: coordinate)
        }
    }

    func setHorizon(_ horizon: HorizonProfile) {
        guard var existing = spot else { return }
        existing.horizon = horizon
        spot = existing
    }

    /// Jumps to a time on the day currently being viewed.
    func scrub(toMinuteOfDay minute: Int) {
        guard let spot else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = spot.timeZone
        let startOfDay = calendar.startOfDay(for: viewedDate)
        viewedDate = startOfDay.addingTimeInterval(Double(minute) * 60)
        followsClock = false
    }

    /// Returns to following the clock.
    func returnToNow() {
        viewedDate = .now
        followsClock = true
    }

    /// Called on the app's timer. Only advances while the person has not taken control.
    func clockTicked(to date: Date) {
        guard followsClock else { return }
        viewedDate = date
    }

    /// Minutes since local midnight for the viewed moment, for driving a slider.
    var viewedMinuteOfDay: Int {
        guard let spot else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = spot.timeZone
        let startOfDay = calendar.startOfDay(for: viewedDate)
        return Int(viewedDate.timeIntervalSince(startOfDay) / 60)
    }
}
