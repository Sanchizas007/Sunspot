import SwiftUI
import SolarCore

/// The first screen: what this spot gets today, answered before it is explained.
struct TodayView: View {
    @Environment(LocationProvider.self) private var location

    @State private var now = Date()
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var spot: Spot? {
        guard case let .located(latitude, longitude) = location.state else { return nil }
        return Spot(
            name: "Here",
            coordinate: GeoCoordinate(latitude: latitude, longitude: longitude)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let spot {
                    SunSummary(spot: spot, now: now)
                } else {
                    LocationPrompt(state: location.state) { location.start() }
                }
            }
            .navigationTitle("Today")
        }
        .onAppear { location.start() }
        .onReceive(tick) { now = $0 }
    }
}

private struct SunSummary: View {
    let spot: Spot
    let now: Date

    private var day: SunDay { spot.sunDay(on: now) }
    private var sun: SolarPosition { spot.sunPosition(at: now) }

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
