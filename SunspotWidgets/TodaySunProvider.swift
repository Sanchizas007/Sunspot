import WidgetKit
import Foundation
import SolarCore
import SpotKit

/// Works out what to show, and when to look again.
struct TodaySunProvider: TimelineProvider {

    func placeholder(in context: Context) -> TodaySunEntry {
        .placeholder()
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaySunEntry) -> Void) {
        // The gallery preview should look like a real reading rather than an empty state.
        completion(context.isPreview ? .placeholder() : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaySunEntry>) -> Void) {
        let now = Date()
        let entries = Unlock.isUnlocked
            ? upcoming(from: now)
            : [TodaySunEntry(date: now, state: .locked)]

        // Refreshed after the last entry, or just after midnight, whichever comes first: the
        // figure is a whole day's total and only changes when the day does.
        let next = entries.last?.date.addingTimeInterval(3600) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(min(next, midnightAfter(now)))))
    }

    /// A handful of entries through the day, so the times stay current without waking the
    /// extension every few minutes.
    private func upcoming(from now: Date) -> [TodaySunEntry] {
        stride(from: 0, through: 6, by: 1).map { hours in
            entry(at: now.addingTimeInterval(Double(hours) * 3600))
        }
    }

    private func entry(at date: Date) -> TodaySunEntry {
        guard let archive = try? SpotArchive(), let spot = archive.loadIgnoringDamage().first else {
            return TodaySunEntry(date: date, state: .noSpot)
        }
        let day = spot.sunDay(on: date)
        return TodaySunEntry(date: date, state: .reading(TodaySunEntry.Reading(
            name: spot.name,
            directMinutes: day.directMinutes,
            exposure: day.exposure,
            firstSun: day.firstSun,
            lastSun: day.lastSun,
            timeZone: spot.timeZone,
            measured: spot.hasMeasuredSkyline
        )))
    }

    private func midnightAfter(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.nextDate(
            after: date, matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(3600)
    }
}
