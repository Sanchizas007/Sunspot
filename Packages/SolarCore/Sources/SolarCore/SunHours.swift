import Foundation

/// How a spot rates against the wording on a seed packet or a plant label.
///
/// The thresholds are the ones growers use: six hours of direct sun and up is full sun,
/// under two is full shade.
public enum SunExposure: String, Sendable, CaseIterable {
    case fullSun
    case partSun
    case partShade
    case fullShade

    public init(directMinutes: Int) {
        switch directMinutes {
        case 360...: self = .fullSun
        case 240..<360: self = .partSun
        case 120..<240: self = .partShade
        default: self = .fullShade
        }
    }
}

/// What one spot gets on one day.
public struct SunDay: Sendable, Equatable {
    /// Stretches of direct sun, in order through the day.
    public var intervals: [DateInterval]
    /// Total direct sun, in whole minutes.
    public var directMinutes: Int
    /// When the sun first reaches the spot, if it ever does.
    public var firstSun: Date?
    /// When it leaves for the last time.
    public var lastSun: Date?
    /// The longest unbroken stretch, in whole minutes. What matters for ripening.
    public var longestStretchMinutes: Int

    public var exposure: SunExposure { SunExposure(directMinutes: directMinutes) }
}

extension Solar {

    /// How closely to walk the day.
    ///
    /// The sun moves smoothly, so a coarser walk changes a day's total by a few minutes at
    /// most — but it changes a year's computation from seconds to a blink, which is the
    /// difference between a chart that appears and one that hangs the screen.
    public enum Resolution: Sendable {
        /// Every minute. For the day in front of someone.
        case exact
        /// Every five minutes. For a year at a glance.
        case survey

        var step: TimeInterval {
            switch self {
            case .exact: 60
            case .survey: 300
            }
        }
    }

    /// Walks one local day a minute at a time and counts only the light that actually
    /// reaches the spot.
    ///
    /// - Parameters:
    ///   - day: any instant inside the day of interest.
    ///   - coordinate: where the spot is.
    ///   - timeZone: which day. Defaults to the device's.
    ///   - horizon: the skyline around the spot. Defaults to open sky.
    public static func sunDay(
        containing day: Date,
        coordinate: GeoCoordinate,
        timeZone: TimeZone = .current,
        horizon: HorizonProfile = .open,
        resolution: Resolution = .exact
    ) -> SunDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)

        let step = resolution.step

        var intervals: [DateInterval] = []
        var runStart: Date?
        var previousLit = false

        var cursor = start
        while cursor < end {
            let lit = isSunDirect(at: cursor, coordinate: coordinate, horizon: horizon)
            if lit && !previousLit {
                let previous = cursor.addingTimeInterval(-step)
                runStart = cursor > start
                    ? refineTransition(between: cursor, and: previous,
                                       coordinate: coordinate, horizon: horizon)
                    : cursor
            } else if !lit, previousLit, let began = runStart {
                let previous = cursor.addingTimeInterval(-step)
                let ends = refineTransition(between: previous, and: cursor,
                                            coordinate: coordinate, horizon: horizon)
                intervals.append(DateInterval(start: began, end: ends))
                runStart = nil
            }
            previousLit = lit
            cursor.addTimeInterval(step)
        }
        if let began = runStart {
            intervals.append(DateInterval(start: began, end: end))
        }

        let totalSeconds = intervals.reduce(0) { $0 + $1.duration }
        let longestSeconds = intervals.map(\.duration).max() ?? 0

        return SunDay(
            intervals: intervals,
            directMinutes: Int((totalSeconds / 60).rounded()),
            firstSun: intervals.first?.start,
            lastSun: intervals.last?.end,
            longestStretchMinutes: Int((longestSeconds / 60).rounded())
        )
    }

    /// Half the width of the sun's disc: 16 arcminutes.
    public static let solarSemidiameter = 16.0 / 60

    /// Standard atmospheric refraction at the horizon: 34 arcminutes.
    public static let horizonRefraction = 34.0 / 60

    /// How high the sun's visible upper edge sits, given the centre's geometric elevation.
    ///
    /// The two corrections are the ones every almanac folds into the definition of sunrise:
    /// the atmosphere lifts the whole disc by about 34 arcminutes, and the disc's own radius
    /// adds another 16. Together they put sunrise at a geometric elevation of −0.833°, which
    /// is the figure weather services and almanacs publish.
    public static func upperLimbElevation(forGeometricCentre elevation: Double) -> Double {
        elevation + horizonRefraction + solarSemidiameter
    }

    /// True when any part of the sun's disc clears the skyline at this moment.
    ///
    /// Getting this right matters more than it looks. Comparing the bare geometric centre
    /// against a flat horizon costs a spot five to twelve minutes at each end of the day,
    /// depending on latitude — a quarter hour of sun that a gardener would notice.
    public static func isSunDirect(
        at date: Date,
        coordinate: GeoCoordinate,
        horizon: HorizonProfile = .open
    ) -> Bool {
        let sun = position(at: date, coordinate: coordinate)
        return upperLimbElevation(forGeometricCentre: sun.elevation)
            > horizon.obstructionElevation(atAzimuth: sun.azimuth)
    }

    /// Narrows a known transition down to the second by bisection.
    ///
    /// Sampling every minute would leave first and last sun up to a minute out, and the
    /// error would always fall the same way — shortening the day. Ten halvings of a
    /// one-minute window settle it to well under a second.
    static func refineTransition(
        between litSide: Date,
        and darkSide: Date,
        coordinate: GeoCoordinate,
        horizon: HorizonProfile
    ) -> Date {
        var lit = litSide
        var dark = darkSide
        for _ in 0..<10 {
            let middle = Date(timeIntervalSince1970: (lit.timeIntervalSince1970 + dark.timeIntervalSince1970) / 2)
            if isSunDirect(at: middle, coordinate: coordinate, horizon: horizon) {
                lit = middle
            } else {
                dark = middle
            }
        }
        // Report the moment the sun is there, rounded to the second the user would read.
        let boundary = min(lit.timeIntervalSince1970, dark.timeIntervalSince1970)
        return Date(timeIntervalSince1970: boundary.rounded())
    }

    /// The stretch of horizon the sun actually crosses at a place over a year.
    ///
    /// Only this part is worth tracing. North of the tropics the sun never appears in the
    /// northern sky in winter and barely does in summer, so asking someone to walk the whole
    /// circle would be asking for work that changes nothing.
    ///
    /// Returned as a starting bearing and a width, both in degrees, walking clockwise.
    public static func sunAzimuthRange(
        coordinate: GeoCoordinate,
        year: Int,
        timeZone: TimeZone = .current
    ) -> (start: Double, width: Double)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let january = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let june = calendar.date(from: DateComponents(year: year, month: 6, day: 21))
        else { return nil }

        // The two solstices bound the year: every other day's arc lies between them.
        var bearings: [Double] = []
        for day in [january, june, calendar.date(byAdding: .month, value: 11, to: january) ?? january] {
            let start = calendar.startOfDay(for: day)
            for minute in stride(from: 0, to: 1440, by: 5) {
                let instant = start.addingTimeInterval(Double(minute) * 60)
                let sun = position(at: instant, coordinate: coordinate)
                if sun.elevation > 0 { bearings.append(sun.azimuth) }
            }
        }
        guard !bearings.isEmpty else { return nil }

        // Find the widest empty wedge; what is left is the arc the sun uses.
        let sorted = bearings.sorted()
        var gapStart = sorted[sorted.count - 1]
        var widestGap = wrap360(sorted[0] - sorted[sorted.count - 1])
        for index in 0..<(sorted.count - 1) {
            let gap = sorted[index + 1] - sorted[index]
            if gap > widestGap {
                widestGap = gap
                gapStart = sorted[index]
            }
        }
        return (start: wrap360(gapStart + widestGap), width: 360 - widestGap)
    }

    /// Direct sun for every day of a year, for drawing the shape of the season.
    ///
    /// This is the figure that settles arguments: the bed that bakes in July sitting in
    /// shadow from October.
    public static func sunYear(
        year: Int,
        coordinate: GeoCoordinate,
        timeZone: TimeZone = .current,
        horizon: HorizonProfile = .open,
        resolution: Resolution = .survey,
        everyNthDay: Int = 1
    ) -> [(date: Date, directMinutes: Int)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
            return []
        }
        let dayCount = calendar.range(of: .day, in: .year, for: start)?.count ?? 365

        return stride(from: 0, to: dayCount, by: max(1, everyNthDay)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let result = sunDay(
                containing: day, coordinate: coordinate, timeZone: timeZone,
                horizon: horizon, resolution: resolution
            )
            return (day, result.directMinutes)
        }
    }
}
