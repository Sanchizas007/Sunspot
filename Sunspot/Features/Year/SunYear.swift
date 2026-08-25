import Foundation
import SpotKit
import SolarCore

/// A whole year of direct sun at one spot, and the plain answers hidden in it.
///
/// The day figure tells you about today. The year is where the useful thing lives: a bed
/// that bakes all July and sits in shadow from October looks perfectly good on the morning
/// somebody decides to plant it.
struct SunYear: Equatable {

    struct Day: Equatable, Identifiable {
        let date: Date
        let minutes: Int
        var id: Date { date }
        var exposure: SunExposure { SunExposure(directMinutes: minutes) }
    }

    let year: Int
    let days: [Day]

    /// Sampled every other day at five-minute resolution.
    ///
    /// Both are deliberate. Walking every minute of every day is over half a million sun
    /// positions and takes seconds on a phone; at five minutes the totals here came out
    /// identical, and the curve is smooth enough that a day either side changes nothing
    /// anyone can see.
    init(spot: Spot, year: Int) {
        self.year = year
        self.days = Solar.sunYear(
            year: year,
            coordinate: spot.coordinate,
            timeZone: spot.timeZone,
            horizon: spot.effectiveHorizon,
            resolution: .survey,
            everyNthDay: 2
        ).map { Day(date: $0.date, minutes: $0.directMinutes) }
    }

    init(year: Int, days: [Day]) {
        self.year = year
        self.days = days
    }

    // MARK: - What the year says

    var sunniest: Day? { days.max { $0.minutes < $1.minutes } }
    var darkest: Day? { days.min { $0.minutes < $1.minutes } }

    /// The longest unbroken run of days that reach a grade, as dates.
    ///
    /// The longest run rather than every run: a spot that scrapes six hours for three days in
    /// March and then loses it again has not got a growing season, and saying so would be
    /// more precise than true.
    ///
    /// A run that reaches both ends of the calendar is joined across the new year. Seasons do
    /// not care where January is: a southern summer runs from November into February, and a
    /// northern dark spell from December into January. Reporting either as ending on the
    /// thirty-first of December would be an artefact of the calendar, not a fact about the
    /// spot.
    func season(atLeast exposure: SunExposure) -> ClosedRange<Date>? {
        let threshold = Self.minimumMinutes(for: exposure)
        return longestRun { $0.minutes >= threshold }
    }

    /// The longest run of days with no direct sun at all, joined across the new year.
    var blackout: ClosedRange<Date>? {
        longestRun { $0.minutes == 0 }
    }

    /// Finds the longest circular run of days satisfying a condition.
    private func longestRun(where matches: (Day) -> Bool) -> ClosedRange<Date>? {
        guard !days.isEmpty else { return nil }

        // Index ranges first: dates are awkward to join across a year boundary, positions
        // are not.
        var runs: [ClosedRange<Int>] = []
        var start: Int?
        for index in days.indices {
            if matches(days[index]) {
                if start == nil { start = index }
            } else if let began = start {
                runs.append(began...(index - 1))
                start = nil
            }
        }
        if let began = start { runs.append(began...(days.count - 1)) }
        guard !runs.isEmpty else { return nil }

        // A run touching both ends is one run wrapped around the turn of the year.
        //
        // Held as two loose ends rather than a range: the start index is late in the year and
        // the end index early, and a ClosedRange refuses to be built backwards.
        var wrapped: (from: Int, to: Int, length: Int)?
        if runs.count > 1,
           runs.first!.lowerBound == 0,
           runs.last!.upperBound == days.count - 1 {
            let leading = runs.removeFirst()
            let trailing = runs.removeLast()
            wrapped = (from: trailing.lowerBound, to: leading.upperBound,
                       length: trailing.count + leading.count)
        } else if runs.count == 1,
                  runs[0].lowerBound == 0,
                  runs[0].upperBound == days.count - 1 {
            // The whole year.
            return days.first!.date...days.last!.date
        }

        let bestPlain = runs.max { $0.count < $1.count }
        let plainLength = bestPlain?.count ?? 0

        if let wrapped, wrapped.length >= plainLength {
            let from = days[wrapped.from].date
            // The far end belongs to the following year, so the range reads forwards.
            let rawEnd = days[wrapped.to].date
            let end = Calendar.current.date(byAdding: .year, value: 1, to: rawEnd) ?? rawEnd
            return from...end
        }
        guard let bestPlain else { return nil }
        return days[bestPlain.lowerBound].date...days[bestPlain.upperBound].date
    }

    /// True when the spot never manages the grade at any point in the year.
    func neverReaches(_ exposure: SunExposure) -> Bool {
        season(atLeast: exposure) == nil
    }

    // MARK: - Helpers

    static func minimumMinutes(for exposure: SunExposure) -> Int {
        switch exposure {
        case .fullSun: 360
        case .partSun: 240
        case .partShade: 120
        case .fullShade: 0
        }
    }

    private static func longer(
        _ current: ClosedRange<Date>?, _ candidate: ClosedRange<Date>
    ) -> ClosedRange<Date> {
        guard let current else { return candidate }
        let currentLength = current.upperBound.timeIntervalSince(current.lowerBound)
        let candidateLength = candidate.upperBound.timeIntervalSince(candidate.lowerBound)
        return candidateLength > currentLength ? candidate : current
    }
}
