import UserNotifications
import Foundation
import Observation
import SolarCore
import SpotKit

/// Tells someone the sun is about to reach their spot.
///
/// This is the part that works while the app is shut. Everything else here answers a question
/// somebody thought to ask; this one arrives on its own, at the only moment it is useful —
/// which for a bed that gets four hours in March is a moment worth not missing.
@MainActor
@Observable
final class SunAlerts {

    /// How far ahead to schedule. Notifications are scheduled by the system, not by us, and
    /// iOS keeps at most sixty-four pending per app — a week for a handful of spots fits
    /// comfortably, and the app reschedules every time it opens.
    static let daysAhead = 7

    /// Default warning, long enough to put boots on.
    static let defaultLeadMinutes = 20

    enum Permission: Equatable {
        case unknown
        case granted
        case denied
    }

    private(set) var permission: Permission = .unknown

    private let centre = UNUserNotificationCenter.current()

    // MARK: - Permission

    func refreshPermission() async {
        let settings = await centre.notificationSettings()
        permission = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        default: .unknown
        }
    }

    /// Asks, once. Returns whether alerts can now be delivered.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await centre.requestAuthorization(options: [.alert, .sound])
            permission = granted ? .granted : .denied
            return granted
        } catch {
            permission = .denied
            return false
        }
    }

    // MARK: - Scheduling

    /// Rebuilds every pending alert from the spots as they stand.
    ///
    /// Wholesale rather than incremental on purpose: a spot can move, be retraced, be renamed
    /// or be deleted, and each of those changes what should be delivered. Working out the
    /// difference would be more code and more ways to leave a stale notification behind.
    func reschedule(for spots: [Spot], from now: Date = .now) async {
        centre.removeAllPendingNotificationRequests()
        guard permission == .granted else { return }

        for spot in spots {
            guard let lead = spot.alertMinutesBefore else { continue }
            for request in Self.requests(for: spot, leadMinutes: lead, from: now) {
                try? await centre.add(request)
            }
        }
    }

    /// The notifications a single spot deserves over the coming week.
    static func requests(
        for spot: Spot, leadMinutes: Int, from now: Date, days: Int = daysAhead
    ) -> [UNNotificationRequest] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = spot.timeZone

        return (0..<days).compactMap { offset -> UNNotificationRequest? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let firstSun = spot.sunDay(on: day).firstSun
            else { return nil }

            let fireAt = firstSun.addingTimeInterval(-Double(leadMinutes) * 60)
            // A warning that has already passed is not a warning.
            guard fireAt > now else { return nil }

            let content = UNMutableNotificationContent()
            content.title = spot.name
            content.body = Self.wording(
                minutesBefore: leadMinutes, arrival: firstSun, timeZone: spot.timeZone
            )
            content.sound = .default

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireAt
            )
            return UNNotificationRequest(
                identifier: "sun-\(spot.id.uuidString)-\(offset)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }

    /// What the notification actually says.
    static func wording(minutesBefore: Int, arrival: Date, timeZone: TimeZone) -> String {
        let at = Format.time(arrival, in: timeZone)
        return switch minutesBefore {
        case 0: String(localized: "The sun is reaching this spot now.")
        case 1: String(localized: "The sun reaches this spot in a minute, at \(at).")
        case 2...90: String(localized: "The sun reaches this spot in \(minutesBefore) minutes, at \(at).")
        default: String(localized: "The sun reaches this spot at \(at).")
        }
    }

    /// Removes everything, for switching alerts off entirely.
    func cancelAll() {
        centre.removeAllPendingNotificationRequests()
    }
}
