import Testing
import Foundation
import SolarCore
@testable import Sunspot

@MainActor
struct SpotStoreTests {

    static let kyiv = GeoCoordinate(latitude: 50.4501, longitude: 30.5234)
    static let lviv = GeoCoordinate(latitude: 49.8397, longitude: 24.0297)

    @Test("The first position from the device becomes the spot")
    func adoptsFirstDeviceLocation() {
        let store = SpotStore()
        #expect(store.spot == nil)
        store.adoptDeviceLocation(latitude: 50.4501, longitude: 30.5234)
        #expect(store.spot?.coordinate == Self.kyiv)
    }

    @Test("A later position never yanks the pin away from where it was put")
    func deviceLocationDoesNotOverridePlacedSpot() {
        // Someone walking around the garden with the app open would otherwise watch their
        // carefully placed pin jump every time the phone got a better fix.
        let store = SpotStore()
        store.move(to: Self.kyiv)
        store.adoptDeviceLocation(latitude: Self.lviv.latitude, longitude: Self.lviv.longitude)
        #expect(store.spot?.coordinate == Self.kyiv)
    }

    @Test("Moving the spot keeps the skyline already traced for it")
    func movingKeepsTheHorizon() {
        let store = SpotStore()
        store.move(to: Self.kyiv)
        store.setHorizon(HorizonProfile(samples: [.init(azimuth: 180, elevation: 30)]))
        store.move(to: Self.lviv)

        #expect(store.spot?.coordinate == Self.lviv)
        #expect(store.spot?.hasMeasuredSkyline == true)
        #expect(store.spot?.horizon.obstructionElevation(atAzimuth: 180) == 30)
    }

    @Test("Scrubbing takes control of the clock, and Now gives it back")
    func scrubbingTakesOverTheClock() {
        let store = SpotStore()
        store.move(to: Self.kyiv)
        #expect(store.followsClock)

        store.scrub(toMinuteOfDay: 9 * 60)
        #expect(!store.followsClock)
        #expect(store.viewedMinuteOfDay == 9 * 60)

        store.returnToNow()
        #expect(store.followsClock)
    }

    @Test("The clock only moves the view while nobody is scrubbing")
    func clockDoesNotFightTheScrubber() {
        let store = SpotStore()
        store.move(to: Self.kyiv)
        store.scrub(toMinuteOfDay: 6 * 60)
        let held = store.viewedDate

        store.clockTicked(to: .now.addingTimeInterval(3600))
        #expect(store.viewedDate == held, "a tick moved the view out from under the scrubber")

        store.returnToNow()
        let future = Date.now.addingTimeInterval(3600)
        store.clockTicked(to: future)
        #expect(store.viewedDate == future)
    }

    @Test("Scrubbing to a minute and reading it back gives the same minute")
    func scrubRoundTrips() {
        let store = SpotStore()
        store.move(to: Self.kyiv)
        for minute in [0, 1, 359, 720, 1080, 1439] {
            store.scrub(toMinuteOfDay: minute)
            #expect(store.viewedMinuteOfDay == minute, "minute \(minute) came back as \(store.viewedMinuteOfDay)")
        }
    }

    @Test("Scrubbing before a spot exists does nothing rather than crashing")
    func scrubbingWithoutASpotIsSafe() {
        let store = SpotStore()
        store.scrub(toMinuteOfDay: 600)
        #expect(store.spot == nil)
        #expect(store.viewedMinuteOfDay == 0)
    }
}
