import Foundation
import SolarCore

/// Turns numbers into the words a person would use, in their own language.
///
/// Sun apps lose people here more than anywhere else — a screen of bearings and decimals
/// reads as an instrument, not an answer. Every figure the app shows goes through this.
///
/// The wording is localised rather than assembled from parts. "6h 20m" is not the shape a
/// German or a French reader expects, and neither is a bearing spelled in English.
public enum Format {

    private static func localised(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

    /// "6h 20m", "45m", "none" — and their equivalents elsewhere.
    public static func duration(minutes: Int) -> String {
        guard minutes > 0 else { return localised("duration.none") }
        let hours = minutes / 60
        let remainder = minutes % 60

        if hours == 0 {
            return String(format: localised("duration.minutes"), remainder)
        }
        if remainder == 0 {
            return String(format: localised("duration.hours"), hours)
        }
        return String(format: localised("duration.hoursMinutes"), hours, remainder)
    }

    public static func time(_ date: Date?, in timeZone: TimeZone) -> String {
        guard let date else { return "—" }
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// "34°" above the horizon, or a phrase for below it.
    public static func angle(_ degrees: Double) -> String {
        degrees < 0
            ? localised("angle.belowHorizon")
            : "\(Int(degrees.rounded()))°"
    }

    /// "south-east (137°)" — the word first, because that is what people picture.
    public static func compass(_ azimuth: Double) -> String {
        let points: [String.LocalizationValue] = [
            "compass.n", "compass.ne", "compass.e", "compass.se",
            "compass.s", "compass.sw", "compass.w", "compass.nw"
        ]
        let index = Int(((azimuth + 22.5) / 45).rounded(.down)) % points.count
        return String(
            format: localised("compass.withBearing"),
            localised(points[index]),
            Int(azimuth.rounded())
        )
    }

    /// "12 Mar" — a day without the year, because the year is the point of that screen.
    public static func day(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// "12 Mar – 28 Sep", or a phrase when a window covers the whole year.
    public static func dateRange(_ range: ClosedRange<Date>, in timeZone: TimeZone) -> String {
        let days = range.upperBound.timeIntervalSince(range.lowerBound) / 86400
        if days > 355 { return localised("dateRange.allYear") }
        return "\(day(range.lowerBound, in: timeZone)) – \(day(range.upperBound, in: timeZone))"
    }

    /// "6h", "4.5h" — for stating a requirement rather than a measurement.
    public static func hours(_ value: Double) -> String {
        let number = value == value.rounded()
            ? "\(Int(value))"
            : String(format: "%.1f", value)
        return String(format: localised("hours.short"), number)
    }

    public static func coordinate(_ value: Double) -> String {
        String(format: "%.4f°", value)
    }
}
