import SwiftUI

@main
struct SunspotApp: App {
    @State private var location = LocationProvider()

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environment(location)
        }
    }
}
