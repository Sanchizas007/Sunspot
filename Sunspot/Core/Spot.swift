import Foundation
import SolarCore

/// A place the person cares about, and what the sun does to it.
///
/// A spot is deliberately more than a coordinate: the whole point of the app is that two
/// places a few metres apart get very different amounts of sun, because one of them has a
/// garage to the south of it.
struct Spot: Identifiable, Equatable, Codable {
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

    // MARK: - Storing

    private enum CodingKeys: String, CodingKey {
        case id, name, coordinate, horizon, timeZoneIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        coordinate = try container.decode(GeoCoordinate.self, forKey: .coordinate)
        horizon = try container.decode(HorizonProfile.self, forKey: .horizon)
        // A time zone identifier travels; a raw offset does not survive a change of season
        // or a move. If the saved one is no longer known, fall back to the device's.
        let identifier = try container.decode(String.self, forKey: .timeZoneIdentifier)
        timeZone = TimeZone(identifier: identifier) ?? .current
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(horizon, forKey: .horizon)
        try container.encode(timeZone.identifier, forKey: .timeZoneIdentifier)
    }
}
