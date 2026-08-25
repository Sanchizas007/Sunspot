import Foundation
import SolarCore

/// Turns numbers into the words a person would use.
///
/// Sun apps lose people here more than anywhere else — a screen of bearings and decimals
/// reads as an instrument, not an answer. Every figure the app shows goes through this.
public enum Format {

    /// "6h 20m", "45m", "none".
    public static func duration(minutes: Int) -> String {
        guard minutes > 0 else { return "none" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    public static func time(_ date: Date?, in timeZone: TimeZone) -> String {
        guard let date else { return "—" }
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// "34°" above the horizon, or "below the horizon".
    public static func angle(_ degrees: Double) -> String {
        degrees < 0 ? "below the horizon" : "\(Int(degrees.rounded()))°"
    }

    /// "south-east (137°)" — the word first, because that is what people picture.
    public static func compass(_ azimuth: Double) -> String {
        let points = ["north", "north-east", "east", "south-east",
                      "south", "south-west", "west", "north-west"]
        let index = Int(((azimuth + 22.5) / 45).rounded(.down)) % points.count
        return "\(points[index]) (\(Int(azimuth.rounded()))°)"
    }

    /// "12 Mar" — a day without the year, because the year is the whole point of the screen.
    public static func day(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.day().month(.abbreviated)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// "12 Mar – 28 Sep", or "all year" when a window covers it.
    public static func dateRange(_ range: ClosedRange<Date>, in timeZone: TimeZone) -> String {
        let days = range.upperBound.timeIntervalSince(range.lowerBound) / 86400
        if days > 355 { return "all year" }
        return "\(day(range.lowerBound, in: timeZone)) – \(day(range.upperBound, in: timeZone))"
    }

    public static func coordinate(_ value: Double) -> String {
        String(format: "%.4f°", value)
    }
}
