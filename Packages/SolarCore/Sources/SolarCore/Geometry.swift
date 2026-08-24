import Foundation

/// A point on the Earth's surface.
public struct GeoCoordinate: Sendable, Equatable {
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

/// Wraps an angle into 0..<360.
@inlinable func wrap360(_ degrees: Double) -> Double {
    let r = degrees.truncatingRemainder(dividingBy: 360)
    return r < 0 ? r + 360 : r
}
