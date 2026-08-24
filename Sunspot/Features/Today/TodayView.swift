import SwiftUI
import SolarCore

/// The first screen: what this spot gets today, answered before it is explained.
struct TodayView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(SpotStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if let spot = store.spot {
                    SunSummary(spot: spot, moment: store.viewedDate)
                } else {
                    LocationPrompt(state: location.state) { location.start() }
                }
            }
            .navigationTitle("Today")
        }
    }
}

private struct SunSummary: View {
    let spot: Spot
    let moment: Date

    private var day: SunDay { spot.sunDay(on: moment) }
    private var sun: SolarPosition { spot.sunPosition(at: moment) }

    /// Under open sky the longest stretch is always the whole day, so showing it twice is
    /// noise. It earns its place only once a traced skyline breaks the day up.
    private var dayIsBroken: Bool { day.intervals.count > 1 }

    var body: some View {
        List {
            Section {
                Answer(day: day, measured: spot.hasMeasuredSkyline)
                    .listRowInsets(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
            }

            Section("The day") {
                LabeledContent("First sun", value: Format.time(day.firstSun, in: spot.timeZone))
                LabeledContent("Last sun", value: Format.time(day.lastSun, in: spot.timeZone))
                if dayIsBroken {
                    LabeledContent("Longest stretch",
                                   value: Format.duration(minutes: day.longestStretchMinutes))
                    LabeledContent("Broken into", value: "\(day.intervals.count) stretches")
                }
            }

            Section("Right now") {
                LabeledContent("Sun height", value: Format.angle(sun.elevation))
                LabeledContent("Direction", value: Format.compass(sun.azimuth))
            }
        }
    }
}

/// The number the whole app exists to produce.
private struct Answer: View {
    let day: SunDay
    let measured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Format.duration(minutes: day.directMinutes))
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())

            Text("of direct sun — \(day.exposure.name)")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(day.exposure.meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !measured {
                Label(
                    "Open sky, so this is the most it could get. Trace the roofs and trees to get the real figure.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct LocationPrompt: View {
    let state: LocationProvider.State
    let onRequest: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Where is the spot?", systemImage: "location")
        } description: {
            switch state {
            case .idle, .requesting:
                Text("Sunspot needs a position to work out where the sun travels overhead.")
            case .unavailable(let reason):
                Text(reason)
            case .located:
                Text("")
            }
        } actions: {
            if case .unavailable = state {
                Button("Try again", action: onRequest)
            }
        }
    }
}
