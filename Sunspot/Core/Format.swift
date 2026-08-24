import Foundation

/// Turns numbers into the words a person would use.
///
/// Sun apps lose people here more than anywhere else — a screen of bearings and decimals
/// reads as an instrument, not an answer. Every figure the app shows goes through this.
enum Format {

    /// "6h 20m", "45m", "none".
    static func duration(minutes: Int) -> String {
        guard minutes > 0 else { return "none" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    static func time(_ date: Date?, in timeZone: TimeZone) -> String {
        guard let date else { return "—" }
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// "34°" above the horizon, or "below the horizon".
    static func angle(_ degrees: Double) -> String {
        degrees < 0 ? "below the horizon" : "\(Int(degrees.rounded()))°"
    }

    /// "south-east (137°)" — the word first, because that is what people picture.
    static func compass(_ azimuth: Double) -> String {
        let points = ["north", "north-east", "east", "south-east",
                      "south", "south-west", "west", "north-west"]
        let index = Int(((azimuth + 22.5) / 45).rounded(.down)) % points.count
        return "\(points[index]) (\(Int(azimuth.rounded()))°)"
    }

    static func coordinate(_ value: Double) -> String {
        String(format: "%.4f°", value)
    }
}
