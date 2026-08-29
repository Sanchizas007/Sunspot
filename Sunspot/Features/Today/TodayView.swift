import SwiftUI
import SpotKit
import SolarCore

/// The first screen: what this spot gets today, answered before it is explained.
struct TodayView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(SpotStore.self) private var store

    @State private var renaming: Spot?
    @State private var showingPaywall = false
    @State private var comparing = false
    /// Where this screen has been pushed to. Kept as a value rather than left inside a
    /// `NavigationLink` so that a screenshot run, which never touches the screen, can open
    /// the planting list the same way a finger does.
    @State private var path: [Route] = Demo.screen == .plants ? [.plants] : []

    enum Route: Hashable { case plants }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let spot = store.spot {
                    SunSummary(spot: spot, moment: store.viewedDate)
                } else {
                    LocationPrompt(state: location.state) { location.start() }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .plants:
                    if let spot = store.spot {
                        PlantingView(
                            spot: spot,
                            minutes: spot.sunDay(on: store.viewedDate).directMinutes
                        )
                    }
                }
            }
            .navigationTitle("Today")
            .toolbar {
                if store.spot != nil {
                    SpotPicker(
                        renaming: $renaming,
                        showingPaywall: $showingPaywall,
                        comparing: $comparing
                    )
                }
            }
            .renameSpot($renaming)
            .sheet(isPresented: $showingPaywall) { Paywall() }
            .sheet(isPresented: $comparing) { CompareSpots() }
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

            Section {
                NavigationLink(value: TodayView.Route.plants) {
                    Label("What will grow here", systemImage: "leaf")
                }
            }

            Section("The day") {
                LabeledContent("First sun", value: Format.time(day.firstSun, in: spot.timeZone))
                LabeledContent("Last sun", value: Format.time(day.lastSun, in: spot.timeZone))
                if dayIsBroken {
                    LabeledContent("Longest stretch",
                                   value: Format.duration(minutes: day.longestStretchMinutes))
                    // As a Text rather than a plain value: LabeledContent's `value:` takes a
                    // String, which never reaches the translations.
                    LabeledContent("Broken into") {
                        Text("\(day.intervals.count) stretches")
                    }
                }
            }

            Section("Right now") {
                LabeledContent("Sun height", value: Format.angle(sun.elevation))
                LabeledContent("Direction", value: Format.compass(sun.azimuth))
            }

            AlertRow(spot: spot)
        }
    }
}

/// Offers to say something when the sun arrives, which is the only part of this app that
/// works while it is shut.
private struct AlertRow: View {
    @Environment(SpotStore.self) private var store
    @Environment(Purchases.self) private var purchases
    @Environment(SunAlerts.self) private var alerts

    let spot: Spot

    private var isOn: Bool { spot.alertMinutesBefore != nil }

    var body: some View {
        Section {
            if purchases.isUnlocked {
                Toggle(isOn: Binding(
                    get: { isOn },
                    set: { wanted in Task { await set(wanted) } }
                )) {
                    Label("Tell me when the sun arrives", systemImage: "bell")
                }

                if isOn, let first = spot.sunDay(on: .now).firstSun {
                    Text("\(SunAlerts.defaultLeadMinutes) minutes before — around \(Format.time(first.addingTimeInterval(-Double(SunAlerts.defaultLeadMinutes) * 60), in: spot.timeZone)) tomorrow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                NavigationLink {
                    Paywall()
                } label: {
                    Label("Tell me when the sun arrives", systemImage: "bell")
                }
            }
        } footer: {
            if purchases.isUnlocked, alerts.permission == .denied {
                Text("Notifications are switched off for Sunspot. Turn them on in Settings and this will start working.")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func set(_ wanted: Bool) async {
        guard wanted else {
            store.setAlert(minutesBefore: nil)
            await alerts.reschedule(for: store.spots)
            return
        }
        // Only ask for permission at the moment somebody actually wants the thing it is for.
        guard await alerts.requestPermission() else { return }
        store.setAlert(minutesBefore: SunAlerts.defaultLeadMinutes)
        await alerts.reschedule(for: store.spots)
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
