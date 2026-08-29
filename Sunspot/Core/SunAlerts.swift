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

    /// How far ahead to schedule. Notifications are handed to the system, not delivered by
    /// us, so the app has to keep refilling the week — which it does every time it comes to
    /// the front, in `RootView`.
    static let daysAhead = 7

    /// The most notifications iOS will hold pending for one app.
    ///
    /// Past this, `add` does not deliver and does not usefully complain, and which of them
    /// survives is nobody's decision. A week each for nine spots is already over it, and
    /// there is no limit on spots once the app is paid for — so the week is planned across
    /// all of them together and the soonest ones win. Sixty rather than sixty-four: a little
    /// room, because nothing here should be the thing that finds the exact edge.
    static let pendingLimit = 60

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
        // Asked rather than assumed. On a fresh launch nothing has looked yet and `permission`
        // is still `.unknown`, so a rebuild that trusted it would clear the week and schedule
        // nothing in its place; and permission can be taken away in Settings between one
        // launch and the next without the app being told.
        await refreshPermission()

        centre.removeAllPendingNotificationRequests()
        guard permission == .granted else { return }

        for request in Self.plan(for: spots, from: now) {
            try? await centre.add(request)
        }
    }

    /// Every warning the spots between them deserve, soonest first, and no more of them than
    /// the system will actually hold.
    ///
    /// Planned across all the spots at once rather than a week at a time per spot. Done per
    /// spot, the tenth one silently pushes the whole schedule past what iOS keeps, and what
    /// gets lost is whatever happened to be handed over last — not the least useful.
    static func plan(
        for spots: [Spot], from now: Date, days: Int = daysAhead, limit: Int = pendingLimit
    ) -> [UNNotificationRequest] {
        spots
            .flatMap { spot -> [Planned] in
                guard let lead = spot.alertMinutesBefore else { return [] }
                return planned(for: spot, leadMinutes: lead, from: now, days: days)
            }
            .sorted { $0.fireAt < $1.fireAt }
            .prefix(limit)
            .map(\.request)
    }

    /// A warning and the moment it goes off.
    ///
    /// The moment is carried rather than recovered: a `UNCalendarNotificationTrigger` will
    /// not give it back — `nextTriggerDate()` measures from the real clock — and sorting by
    /// it is the whole point of planning across spots.
    struct Planned {
        let fireAt: Date
        let request: UNNotificationRequest
    }

    /// The notifications a single spot deserves over the coming week.
    static func requests(
        for spot: Spot, leadMinutes: Int, from now: Date, days: Int = daysAhead
    ) -> [UNNotificationRequest] {
        planned(for: spot, leadMinutes: leadMinutes, from: now, days: days).map(\.request)
    }

    /// The same, with the moment each one fires kept alongside it.
    static func planned(
        for spot: Spot, leadMinutes: Int, from now: Date, days: Int = daysAhead
    ) -> [Planned] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = spot.timeZone

        return (0..<days).compactMap { offset -> Planned? in
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
            return Planned(
                fireAt: fireAt,
                request: UNNotificationRequest(
                    identifier: "sun-\(spot.id.uuidString)-\(offset)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
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
