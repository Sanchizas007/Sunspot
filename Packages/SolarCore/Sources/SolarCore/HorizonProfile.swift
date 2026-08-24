import Foundation

/// The skyline around one spot: how high the fence, the garage and next door's tree
/// stand in every direction.
///
/// This is what separates a real answer from a pretty sun arc. The sun's path is the easy
/// half; what decides whether anything grows is what stands in the way.
///
/// A profile is a ring of samples. Between samples the height is interpolated, and the ring
/// wraps around north, so a profile with samples at 350° and 10° interpolates across 0°.
public struct HorizonProfile: Sendable, Equatable, Codable {

    /// One measured point on the skyline.
    public struct Sample: Sendable, Equatable, Codable {
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

    // MARK: - How much has actually been measured

    /// The widest gap between neighbouring samples, in degrees.
    ///
    /// A ring of samples is really a ring of gaps, and the biggest gap is the honest measure
    /// of how much is guesswork. With one sample the gap is the whole circle: that lone
    /// height is applied in every direction, which is how a single tap can turn into a wall
    /// all the way round.
    public var largestGap: Double {
        switch samples.count {
        case 0: return 360
        case 1: return 360
        default:
            var widest = 0.0
            for index in samples.indices {
                let next = samples[(index + 1) % samples.count]
                widest = max(widest, wrap360(next.azimuth - samples[index].azimuth))
            }
            return widest
        }
    }

    /// The arc actually walked over, in degrees: a full turn minus the biggest gap.
    public var measuredArc: Double {
        samples.count < 2 ? 0 : 360 - largestGap
    }

    /// True when the profile says something about a direction rather than guessing.
    ///
    /// The test is local, because that is how the question is really asked: a skyline traced
    /// carefully across the south says nothing trustworthy about the north, and should not
    /// pretend to.
    public func hasMeasurement(near azimuth: Double, within tolerance: Double = 20) -> Bool {
        guard !samples.isEmpty else { return false }
        return samples.contains { abs(signedDifference(from: $0.azimuth, to: azimuth)) <= tolerance }
    }

    // MARK: - Storing and reading back

    private enum CodingKeys: String, CodingKey { case samples }

    /// Decoding goes back through the ordinary initialiser rather than filling the stored
    /// array directly. A profile promises its samples are sorted and hold one entry per
    /// direction, and a file edited by hand — or written by an older version — should not be
    /// able to hand back a profile that quietly breaks that promise.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.decode([Sample].self, forKey: .samples)
        self.init(samples: stored)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(samples, forKey: .samples)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}
