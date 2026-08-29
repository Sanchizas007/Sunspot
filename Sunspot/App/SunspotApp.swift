import SwiftUI
import SpotKit

@main
struct SunspotApp: App {
    @State private var location: LocationProvider
    @State private var store: SpotStore
    @State private var purchases: Purchases
    @State private var alerts: SunAlerts

    init() {
        // Before anything reads the archive: `SpotStore` loads it the moment it is built, so
        // a screenshot run's seed written any later would be a file nobody opens. Does
        // nothing unless the screenshot script asked for it, and does not exist in a release.
        Demo.prepareIfRequested()

        _location = State(initialValue: LocationProvider())
        _store = State(initialValue: SpotStore())
        _purchases = State(initialValue: Purchases())
        _alerts = State(initialValue: SunAlerts())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(location)
                .environment(store)
                .environment(purchases)
                .environment(alerts)
        }
    }
}

/// The four screens, named so something other than a finger can choose between them.
enum MainTab: Hashable {
    case today, map, sky, year

    /// Which tab a screenshot run is asking for. Everything it reaches from Today — the
    /// planting list, the comparison, the paywall — starts on Today.
    init(demoScreen: Demo.Screen?) {
        switch demoScreen {
        case .map: self = .map
        case .sky: self = .sky
        case .year: self = .year
        default: self = .today
        }
    }
}

private struct RootView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(SpotStore.self) private var store
    @Environment(Purchases.self) private var purchases
    @Environment(SunAlerts.self) private var alerts

    @State private var tab = MainTab(demoScreen: Demo.screen)

    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        // The classic tab API rather than iOS 18's `Tab`: this app has no reason to shut
        // out a phone that is two years old, and plenty of the people it is for are using one.
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(MainTab.today)
            SpotMapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(MainTab.map)
            SkyView()
                .tabItem { Label("Sky", systemImage: "camera.viewfinder") }
                .tag(MainTab.sky)
            YearView()
                .tabItem { Label("Year", systemImage: "calendar") }
                .tag(MainTab.year)
        }
        .task {
            location.start()
            purchases.startListening()
            await purchases.load()
        }
        .demoState()
        .onReceive(tick) { store.clockTicked(to: $0) }
        .onChange(of: location.state) { _, state in
            if case let .located(latitude, longitude) = state {
                store.adoptDeviceLocation(latitude: latitude, longitude: longitude)
            }
        }
    }
}
