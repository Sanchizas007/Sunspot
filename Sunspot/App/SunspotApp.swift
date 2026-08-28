import SwiftUI
import SpotKit

@main
struct SunspotApp: App {
    @State private var location = LocationProvider()
    @State private var store = SpotStore()
    @State private var purchases = Purchases()
    @State private var alerts = SunAlerts()

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

private struct RootView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(SpotStore.self) private var store
    @Environment(Purchases.self) private var purchases
    @Environment(SunAlerts.self) private var alerts

    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        // The classic tab API rather than iOS 18's `Tab`: this app has no reason to shut
        // out a phone that is two years old, and plenty of the people it is for are using one.
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            SpotMapView()
                .tabItem { Label("Map", systemImage: "map") }
            SkyView()
                .tabItem { Label("Sky", systemImage: "camera.viewfinder") }
            YearView()
                .tabItem { Label("Year", systemImage: "calendar") }
        }
        .task {
            location.start()
            purchases.startListening()
            await purchases.load()
        }
        .onReceive(tick) { store.clockTicked(to: $0) }
        .onChange(of: location.state) { _, state in
            if case let .located(latitude, longitude) = state {
                store.adoptDeviceLocation(latitude: latitude, longitude: longitude)
            }
        }
    }
}
