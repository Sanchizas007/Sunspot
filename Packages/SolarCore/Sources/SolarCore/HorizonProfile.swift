import Foundation

/// The skyline around one spot: how high the fence, the garage and next door's tree
/// stand in every direction.
///
/// This is what separates a real answer from a pretty sun arc. The sun's path is the easy
/// half; what decides whether anything grows is what stands in the way.
///
/// A profile is a ring of samples. Between samples the height is interpolated, and the ring
/// wraps around north, so a profile with samples at 350° and 10° interpolates across 0°.
public struct HorizonProfile: Sendable, Equatable {

    /// One measured point on the skyline.
    public struct Sample: Sendable, Equatable {
        /// Degrees clockwise from true north.
        public var azimuth: Double
        /// Degrees above the horizontal.
        public var elevation: Double

        public init(azimuth: Double, elevation: Double) {
            self.azimuth = wrap360(azimuth)
            self.elevation = elevation
        }
    }

    /// Samples sorted by azimuth, each azimuth appearing once.
    public private(set) var samples: [Sample]

    /// An unobstructed spot — open sky in every direction.
    public static let open = HorizonProfile(samples: [])

    public init(samples: [Sample]) {
        // Later samples win on a repeated azimuth, so re-measuring a direction corrects it.
        var byAzimuth: [Double: Double] = [:]
        for sample in samples {
            byAzimuth[sample.azimuth.rounded(toPlaces: 4)] = sample.elevation
        }
        self.samples = byAzimuth
            .map { Sample(azimuth: $0.key, elevation: $0.value) }
            .sorted { $0.azimuth < $1.azimuth }
    }

    /// Adds or replaces a measurement.
    public mutating func record(azimuth: Double, elevation: Double) {
        self = HorizonProfile(samples: samples + [Sample(azimuth: azimuth, elevation: elevation)])
    }

    /// How high the skyline stands in one direction, in degrees.
    ///
    /// With no samples the horizon is flat and this is 0. With one sample that height applies
    /// all the way round. Otherwise the two neighbouring samples are interpolated, wrapping
    /// across north when needed.
    public func obstructionElevation(atAzimuth azimuth: Double) -> Double {
        guard let first = samples.first else { return 0 }
        guard samples.count > 1 else { return first.elevation }

        let target = wrap360(azimuth)

        // Exact hit or the gap that contains it.
        for index in samples.indices {
            let lower = samples[index]
            if lower.azimuth == target { return lower.elevation }

            let upper = samples[(index + 1) % samples.count]
            let span = wrap360(upper.azimuth - lower.azimuth)
            let offset = wrap360(target - lower.azimuth)
            if offset < span {
                guard span > 0 else { return lower.elevation }
                let fraction = offset / span
                return lower.elevation + (upper.elevation - lower.elevation) * fraction
            }
        }
        return first.elevation
    }

    /// True when the sun at this position is blocked by the skyline.
    public func blocks(_ position: SolarPosition) -> Bool {
        position.elevation <= obstructionElevation(atAzimuth: position.azimuth)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
