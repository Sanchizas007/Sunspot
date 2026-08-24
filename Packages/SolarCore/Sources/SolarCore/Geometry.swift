import Foundation

/// A point on the Earth's surface.
public struct GeoCoordinate: Sendable, Equatable, Codable {
    /// Degrees north of the equator. Negative south.
    public var latitude: Double
    /// Degrees east of Greenwich. Negative west.
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Where the sun is in the sky, seen from one spot.
public struct SolarPosition: Sendable, Equatable {
    /// Degrees clockwise from true north. 0 is north, 90 east, 180 south, 270 west.
    public var azimuth: Double
    /// Degrees above the horizon. Negative when the sun is below it.
    public var elevation: Double

    public init(azimuth: Double, elevation: Double) {
        self.azimuth = azimuth
        self.elevation = elevation
    }
}

@inlinable func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
@inlinable func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

/// The shortest way round from one bearing to another, in −180…180.
@inlinable func signedDifference(from: Double, to: Double) -> Double {
    let raw = wrap360(to - from)
    return raw > 180 ? raw - 360 : raw
}

/// Wraps an angle into 0..<360.
@inlinable func wrap360(_ degrees: Double) -> Double {
    let r = degrees.truncatingRemainder(dividingBy: 360)
    return r < 0 ? r + 360 : r
}

extension GeoCoordinate {

    /// Mean radius of the Earth, in metres.
    public static let earthRadius = 6_371_008.8

    /// The point you reach by setting off along a bearing and walking a given distance.
    ///
    /// Used to draw the sun's direction on a map: a ray from the spot along the azimuth of
    /// sunrise, of sunset, or of the sun right now. Over the few kilometres those rays span,
    /// treating the Earth as a sphere is accurate to a handful of metres — far below what a
    /// map at that zoom can show.
    ///
    /// - Parameters:
    ///   - azimuth: degrees clockwise from true north.
    ///   - distance: metres along the surface.
    public func destination(atAzimuth azimuth: Double, distance: Double) -> GeoCoordinate {
        guard distance != 0 else { return self }

        let angular = distance / Self.earthRadius
        let bearing = radians(wrap360(azimuth))
        let lat1 = radians(latitude)
        let lon1 = radians(longitude)

        let sinLat2 = sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(bearing)
        let lat2 = asin(min(1, max(-1, sinLat2)))
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angular) * cos(lat1),
            cos(angular) - sin(lat1) * sinLat2
        )

        // Fold longitude back into −180…180 so map frameworks do not draw a line round the world.
        var degreesLon = degrees(lon2)
        degreesLon = (degreesLon + 540).truncatingRemainder(dividingBy: 360) - 180

        return GeoCoordinate(latitude: degrees(lat2), longitude: degreesLon)
    }
}
