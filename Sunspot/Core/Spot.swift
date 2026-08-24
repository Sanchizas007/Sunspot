import Foundation
import SolarCore

/// A place the person cares about, and what the sun does to it.
///
/// A spot is deliberately more than a coordinate: the whole point of the app is that two
/// places a few metres apart get very different amounts of sun, because one of them has a
/// garage to the south of it.
struct Spot: Identifiable, Equatable {
    let id: UUID
    var name: String
    var coordinate: GeoCoordinate
    var horizon: HorizonProfile
    var timeZone: TimeZone

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: GeoCoordinate,
        horizon: HorizonProfile = .open,
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.horizon = horizon
        self.timeZone = timeZone
    }

    /// True once the skyline has been traced. Until then the figures describe open sky,
    /// which is an upper bound rather than an answer.
    var hasMeasuredSkyline: Bool { !horizon.samples.isEmpty }

    func sunDay(on date: Date) -> SunDay {
        Solar.sunDay(containing: date, coordinate: coordinate, timeZone: timeZone, horizon: horizon)
    }

    func sunPosition(at date: Date) -> SolarPosition {
        Solar.position(at: date, coordinate: coordinate)
    }
}
