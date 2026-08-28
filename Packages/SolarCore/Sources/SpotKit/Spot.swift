import Foundation
import SolarCore

/// A place the person cares about, and what the sun does to it.
///
/// A spot is deliberately more than a coordinate: the whole point of the app is that two
/// places a few metres apart get very different amounts of sun, because one of them has a
/// garage to the south of it.
public struct Spot: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var coordinate: GeoCoordinate
    public var horizon: HorizonProfile
    public var timeZone: TimeZone

    /// How long before the sun reaches this spot to say so, in minutes. Nil means stay quiet.
    ///
    /// Kept on the spot rather than in a settings screen: the answer is different for the bed
    /// by the fence and the bed by the garage, and so is whether anybody cares about it.
    public var alertMinutesBefore: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        coordinate: GeoCoordinate,
        horizon: HorizonProfile = .open,
        timeZone: TimeZone = .current,
        alertMinutesBefore: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.horizon = horizon
        self.timeZone = timeZone
        self.alertMinutesBefore = alertMinutesBefore
    }

    /// The narrowest arc worth calling a skyline.
    ///
    /// Below this the samples say nothing about most of the sky, and a profile that thin is
    /// worse than none: one point at 272° was read as a wall in every direction and took a
    /// hundred and sixty-nine minutes off a real answer without saying a word.
    public static let minimumUsefulArc: Double = 30

    /// True once enough of the skyline has been traced to mean something.
    public var hasMeasuredSkyline: Bool { horizon.measuredArc >= Self.minimumUsefulArc }

    /// The skyline actually used in the sums.
    ///
    /// A trace too thin to trust is set aside rather than applied. Open sky is an honest
    /// upper bound and the screen says as much; a confident wrong number is neither.
    public var effectiveHorizon: HorizonProfile { hasMeasuredSkyline ? horizon : .open }

    /// How much of the horizon has been walked over, in degrees.
    public var measuredArc: Double { horizon.measuredArc }

    /// The stretch of horizon the sun crosses here across a year — the only part worth
    /// tracing.
    public func sunArcWidth(in year: Int) -> Double? {
        Solar.sunAzimuthRange(coordinate: coordinate, year: year, timeZone: timeZone)?.width
    }

    public func sunDay(on date: Date) -> SunDay {
        Solar.sunDay(containing: date, coordinate: coordinate, timeZone: timeZone,
                     horizon: effectiveHorizon)
    }

    public func sunPosition(at date: Date) -> SolarPosition {
        Solar.position(at: date, coordinate: coordinate)
    }

    // MARK: - Storing

    private enum CodingKeys: String, CodingKey {
        case id, name, coordinate, horizon, timeZoneIdentifier, alertMinutesBefore
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        coordinate = try container.decode(GeoCoordinate.self, forKey: .coordinate)
        horizon = try container.decode(HorizonProfile.self, forKey: .horizon)
        // A time zone identifier travels; a raw offset does not survive a change of season
        // or a move. If the saved one is no longer known, fall back to the device's.
        let identifier = try container.decode(String.self, forKey: .timeZoneIdentifier)
        timeZone = TimeZone(identifier: identifier) ?? .current
        // Absent in files written before alerts existed, which is the same as switched off.
        alertMinutesBefore = try container.decodeIfPresent(Int.self, forKey: .alertMinutesBefore)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(coordinate, forKey: .coordinate)
        try container.encode(horizon, forKey: .horizon)
        try container.encode(timeZone.identifier, forKey: .timeZoneIdentifier)
        try container.encodeIfPresent(alertMinutesBefore, forKey: .alertMinutesBefore)
    }
}
