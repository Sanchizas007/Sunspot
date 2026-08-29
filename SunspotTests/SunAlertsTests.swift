import Testing
import Foundation
import UserNotifications
import SolarCore
import SpotKit
@testable import Sunspot

/// The only part of this app that works while it is shut, and therefore the only part nobody
/// will see go wrong until they have already missed the afternoon it was meant to catch.
@MainActor
struct SunAlertsTests {

    static let zone = TimeZone(identifier: "Europe/Kyiv")!

    static func spot(
        horizon: HorizonProfile = .open,
        latitude: Double = 47.8388
    ) -> Spot {
        Spot(
            name: "Back bed",
            coordinate: GeoCoordinate(latitude: latitude, longitude: 35.1495),
            horizon: horizon,
            timeZone: zone
        )
    }

    /// When a request will actually fire.
    ///
    /// Read from the trigger's own components rather than `nextTriggerDate()`, which measures
    /// against the real clock and so reports nothing at all for any date these tests simulate.
    static func fireDate(of request: UNNotificationRequest) -> Date? {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: trigger.dateComponents)
    }

    static func moment(_ month: Int, _ day: Int, hour: Int = 3) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(
            year: 2026, month: month, day: day, hour: hour
        ))!
    }

    // MARK: - What gets scheduled

    @Test("A week of warnings is scheduled, one for each day")
    func schedulesAWeek() {
        let requests = SunAlerts.requests(
            for: Self.spot(), leadMinutes: 20, from: Self.moment(6, 1)
        )
        #expect(requests.count == SunAlerts.daysAhead, "got \(requests.count)")
        #expect(Set(requests.map(\.identifier)).count == requests.count,
                "two notifications shared an identifier and would overwrite each other")
    }

    @Test("Each warning lands the right distance before the sun arrives")
    func firesTheStatedNumberOfMinutesEarly() throws {
        let spot = Self.spot()
        let now = Self.moment(6, 1)
        let request = try #require(SunAlerts.requests(for: spot, leadMinutes: 20, from: now).first)

        let fireAt = try #require(Self.fireDate(of: request))
        let arrival = try #require(spot.sunDay(on: now).firstSun)

        let lead = arrival.timeIntervalSince(fireAt) / 60
        #expect(abs(lead - 20) < 1.5, "warning came \(lead) minutes early instead of 20")
    }

    @Test("A warning whose moment has already gone is not scheduled")
    func skipsWarningsAlreadyPassed() {
        // Midday: this morning's sunrise is hours behind, so today gets nothing and the
        // remaining days still do.
        let requests = SunAlerts.requests(
            for: Self.spot(), leadMinutes: 20, from: Self.moment(6, 1, hour: 12)
        )
        #expect(requests.count == SunAlerts.daysAhead - 1, "got \(requests.count)")

        for request in requests {
            #expect(Self.fireDate(of: request) ?? .distantPast > Self.moment(6, 1, hour: 12),
                    "a notification was scheduled in the past")
        }
    }

    @Test("A spot the sun never reaches is left in silence")
    func noSunMeansNoNotification() {
        // Walled in on every side, in midwinter.
        let enclosed = Self.spot(horizon: HorizonProfile(
            samples: stride(from: 0.0, to: 360.0, by: 15).map { .init(azimuth: $0, elevation: 80) }
        ))
        let requests = SunAlerts.requests(for: enclosed, leadMinutes: 20, from: Self.moment(12, 15))
        #expect(requests.isEmpty, "promised sun that never comes: \(requests.count) notifications")
    }

    @Test("A traced skyline moves the warning later than open sky would")
    func skylineDelaysTheWarning() throws {
        // The point of the whole app: the sun clears the horizon long before it clears the
        // rooftops, and it is the rooftops that matter.
        let now = Self.moment(3, 15)
        let open = try #require(SunAlerts.requests(for: Self.spot(), leadMinutes: 20, from: now).first)
        let walled = try #require(SunAlerts.requests(
            for: Self.spot(horizon: HorizonProfile(samples: [
                .init(azimuth: 60, elevation: 25),
                .init(azimuth: 120, elevation: 25),
                .init(azimuth: 180, elevation: 0),
                .init(azimuth: 300, elevation: 0)
            ])),
            leadMinutes: 20, from: now
        ).first)

        let openFire = try #require(Self.fireDate(of: open))
        let walledFire = try #require(Self.fireDate(of: walled))
        #expect(walledFire > openFire, "the wall should hold the sun off and push the warning later")
    }

    @Test("Every spot gets its own identifiers, so one does not cancel another")
    func identifiersAreSpotSpecific() {
        let fence = Self.spot()
        let balcony = Self.spot()
        let now = Self.moment(6, 1)

        let a = Set(SunAlerts.requests(for: fence, leadMinutes: 20, from: now).map(\.identifier))
        let b = Set(SunAlerts.requests(for: balcony, leadMinutes: 20, from: now).map(\.identifier))
        #expect(a.isDisjoint(with: b), "two spots would fight over the same notifications")
    }

    @Test("The notification names the spot, so several of them stay distinguishable")
    func contentNamesTheSpot() throws {
        let request = try #require(
            SunAlerts.requests(for: Self.spot(), leadMinutes: 20, from: Self.moment(6, 1)).first
        )
        #expect(request.content.title == "Back bed")
        #expect(!request.content.body.isEmpty)
    }

    // MARK: - Planning across several spots

    @Test("The week is planned across all the spots at once, not a week each")
    func planCoversEverySpotWithAlertsOn() {
        var withAlerts = Self.spot()
        withAlerts.alertMinutesBefore = 20
        var alsoOn = Self.spot()
        alsoOn.alertMinutesBefore = 45
        let off = Self.spot()

        let plan = SunAlerts.plan(for: [withAlerts, alsoOn, off], from: Self.moment(6, 1))
        #expect(plan.count == SunAlerts.daysAhead * 2, "got \(plan.count)")
        #expect(Set(plan.map(\.identifier)).count == plan.count,
                "two notifications shared an identifier and would overwrite each other")
    }

    @Test("A spot with alerts switched off contributes nothing")
    func planIgnoresSilentSpots() {
        #expect(SunAlerts.plan(for: [Self.spot(), Self.spot()], from: Self.moment(6, 1)).isEmpty)
    }

    @Test("Past what iOS will hold, the soonest warnings are the ones kept")
    func planKeepsTheSoonestWhenThereAreTooMany() throws {
        // Ten spots at a week each is seventy, and iOS holds sixty-four. Which ten go missing
        // is not something to leave to the order they happened to be added in.
        var spots: [Spot] = []
        for _ in 0..<10 {
            var spot = Self.spot()
            spot.alertMinutesBefore = 20
            spots.append(spot)
        }
        let now = Self.moment(6, 1)
        let plan = SunAlerts.plan(for: spots, from: now)

        #expect(plan.count == SunAlerts.pendingLimit, "got \(plan.count)")

        // Everything kept must fire no later than anything dropped. With ten identical spots
        // that means the last day of the week is what goes, not an arbitrary third of it.
        let kept = plan.compactMap(Self.fireDate(of:))
        let everything = SunAlerts.plan(
            for: spots, from: now, limit: .max
        ).compactMap(Self.fireDate(of:))
        let dropped = everything.sorted().suffix(everything.count - kept.count)
        #expect(kept.max() ?? .distantPast <= dropped.min() ?? .distantFuture,
                "a later warning was kept over an earlier one")
    }

    @Test("The limit stays under what the system will actually hold")
    func limitLeavesRoom() {
        #expect(SunAlerts.pendingLimit <= 64, "iOS keeps at most sixty-four pending per app")
    }

    // MARK: - Wording

    @Test("The wording reads like a sentence at every lead time")
    func wordingIsReadable() {
        let arrival = Self.moment(6, 1, hour: 7)

        #expect(SunAlerts.wording(minutesBefore: 0, arrival: arrival, timeZone: Self.zone)
            .contains("now"))
        #expect(SunAlerts.wording(minutesBefore: 1, arrival: arrival, timeZone: Self.zone)
            .contains("in a minute"), "should not say '1 minutes'")
        #expect(SunAlerts.wording(minutesBefore: 20, arrival: arrival, timeZone: Self.zone)
            .contains("20 minutes"))

        for lead in [0, 1, 5, 20, 45, 120] {
            let text = SunAlerts.wording(minutesBefore: lead, arrival: arrival, timeZone: Self.zone)
            #expect(text.hasSuffix("."), "\(lead): \(text)")
            #expect(!text.contains("  "), "\(lead) produced a double space")
        }
    }

    @Test("A spot with alerts switched off asks for nothing")
    func alertsOffByDefault() {
        #expect(Self.spot().alertMinutesBefore == nil, "alerts must be opt-in")
    }

    @Test("Switching alerts on is remembered across a relaunch")
    func settingSurvivesStorage() throws {
        var spot = Self.spot()
        spot.alertMinutesBefore = 30

        let data = try JSONEncoder().encode(spot)
        let restored = try JSONDecoder().decode(Spot.self, from: data)
        #expect(restored.alertMinutesBefore == 30)
    }

    @Test("A spot saved before alerts existed reads back as switched off")
    func olderFilesDecode() throws {
        // The field is simply absent in anything written by an earlier version.
        let json = """
        {"id":"11111111-2222-3333-4444-555555555555","name":"Old",
         "coordinate":{"latitude":47.8,"longitude":35.1},
         "timeZoneIdentifier":"Europe/Kyiv","horizon":{"samples":[]}}
        """
        let restored = try JSONDecoder().decode(Spot.self, from: Data(json.utf8))
        #expect(restored.alertMinutesBefore == nil)
        #expect(restored.name == "Old")
    }
}
