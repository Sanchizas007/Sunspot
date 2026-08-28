import WidgetKit
import SwiftUI
import SolarCore
import SpotKit

/// Today's hours on the home screen, so the question can be answered without opening anything.
struct TodaySunWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySun", provider: TodaySunProvider()) { entry in
            TodaySunView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sun today")
        .description("Hours of direct sun at your spot, counting the roofs and trees in the way.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodaySunView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodaySunEntry

    var body: some View {
        switch entry.state {
        case .reading(let reading):
            Reading(reading: reading, wide: family == .systemMedium)
        case .noSpot:
            Message(
                icon: "mappin.slash",
                title: "No spot yet",
                detail: "Open Sunspot and trace the skyline where you are."
            )
        case .locked:
            Message(
                icon: "lock",
                title: "Not unlocked",
                detail: "The widget comes with the full picture, in Sunspot."
            )
        }
    }
}

private struct Reading: View {
    let reading: SunSnapshot.Reading
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: wide ? 8 : 4) {
            HStack(spacing: 5) {
                Image(systemName: "sun.max.fill").foregroundStyle(.orange)
                Text(reading.name)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(Format.duration(minutes: reading.directMinutes))
                .font(.system(size: wide ? 40 : 34, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(reading.exposure.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)

            if wide, let first = reading.firstSun, let last = reading.lastSun {
                Text("\(Format.time(first, in: reading.timeZone)) – \(Format.time(last, in: reading.timeZone))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !reading.measured {
                // Never let the home screen state an upper bound as though it were the answer.
                Text("open sky")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct Message: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(.orange)
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
