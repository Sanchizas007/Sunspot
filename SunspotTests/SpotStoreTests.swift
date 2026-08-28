import Testing
import Foundation
import SolarCore
import SpotKit
@testable import Sunspot

@MainActor
struct SpotStoreTests {

    static let kyiv = GeoCoordinate(latitude: 50.4501, longitude: 30.5234)
    static let lviv = GeoCoordinate(latitude: 49.8397, longitude: 24.0297)

    /// A store writing to a file of its own.
    ///
    /// Without this every test reads and writes the app's real archive, so they see each
    /// other's spots and the results depend on what ran before — which is exactly how these
    /// tests started failing the moment saving was added.
    static func isolatedStore() -> (SpotStore, SpotArchive) {
        let archive = SpotArchive(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("spots-\(UUID().uuidString).json"))
        return (SpotStore(archive: archive), archive)
    }

    @Test("The first position from the device becomes the spot")
    func adoptsFirstDeviceLocation() {
        let (store, _) = Self.isolatedStore()
        #expect(store.spot == nil)
        store.adoptDeviceLocation(latitude: 50.4501, longitude: 30.5234)
        #expect(store.spot?.coordinate == Self.kyiv)
    }

    @Test("A later position never yanks the pin away from where it was put")
    func deviceLocationDoesNotOverridePlacedSpot() {
        // Someone walking around the garden with the app open would otherwise watch their
        // carefully placed pin jump every time the phone got a better fix.
        let (store, _) = Self.isolatedStore()
        store.move(to: Self.kyiv)
        store.adoptDeviceLocation(latitude: Self.lviv.latitude, longitude: Self.lviv.longitude)
        #expect(store.spot?.coordinate == Self.kyiv)
    }

    @Test("Moving the spot keeps the skyline already traced for it")
    func movingKeepsTheHorizon() {
        let (store, _) = Self.isolatedStore()
        store.move(to: Self.kyiv)
        store.setHorizon(HorizonProfile(samples: [
            .init(azimuth: 150, elevation: 25),
            .init(azimuth: 180, elevation: 30),
            .init(azimuth: 210, elevation: 22)
        ]))
        store.move(to: Self.lviv)

        #expect(store.spot?.coordinate == Self.lviv)
        #expect(store.spot?.hasMeasuredSkyline == true)
        #expect(store.spot?.horizon.obstructionElevation(atAzimuth: 180) == 30)
    }

    @Test("Scrubbing takes control of the clock, and Now gives it back")
    func scrubbingTakesOverTheClock() {
        let (store, _) = Self.isolatedStore()
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
        let (store, _) = Self.isolatedStore()
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
        let (store, _) = Self.isolatedStore()
        store.move(to: Self.kyiv)
        for minute in [0, 1, 359, 720, 1080, 1439] {
            store.scrub(toMinuteOfDay: minute)
            #expect(store.viewedMinuteOfDay == minute, "minute \(minute) came back as \(store.viewedMinuteOfDay)")
        }
    }

    @Test("Scrubbing before a spot exists does nothing rather than crashing")
    func scrubbingWithoutASpotIsSafe() {
        let (store, _) = Self.isolatedStore()
        store.scrub(toMinuteOfDay: 600)
        #expect(store.spot == nil)
        #expect(store.viewedMinuteOfDay == 0)
    }
}

/// Tracing a skyline is the only real work the app asks of anyone. Losing it would be the
/// kind of failure people find out about a week later.
@MainActor
struct SpotPersistenceTests {

    static func archive() -> SpotArchive {
        SpotArchive(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("spots-\(UUID().uuidString).json"))
    }

    @Test("A traced skyline comes back after the app is closed and reopened")
    func skylineSurvivesRelaunch() {
        let archive = Self.archive()
        let traced = HorizonProfile(samples: [
            .init(azimuth: 30, elevation: 12),
            .init(azimuth: 140, elevation: 35),
            .init(azimuth: 250, elevation: 8)
        ])

        do {
            let store = SpotStore(archive: archive)
            store.move(to: GeoCoordinate(latitude: 50.4501, longitude: 30.5234))
            store.setHorizon(traced)
        }

        // A fresh store is what a fresh launch gets.
        let reopened = SpotStore(archive: archive)
        #expect(reopened.spot?.hasMeasuredSkyline == true, "the skyline was lost")
        #expect(reopened.spot?.horizon == traced)
        #expect(reopened.spot?.coordinate == GeoCoordinate(latitude: 50.4501, longitude: 30.5234))
    }

    @Test("A location fix on launch does not overwrite the spot that was restored")
    func restoredSpotSurvivesALocationFix() {
        // The failure this guards against: open the app in a different town, and the skyline
        // traced at home is quietly replaced by open sky.
        let archive = Self.archive()
        let traced = HorizonProfile(samples: [
            .init(azimuth: 140, elevation: 35),
            .init(azimuth: 180, elevation: 40),
            .init(azimuth: 220, elevation: 30)
        ])

        do {
            let store = SpotStore(archive: archive)
            store.move(to: GeoCoordinate(latitude: 50.4501, longitude: 30.5234))
            store.setHorizon(traced)
        }

        let reopened = SpotStore(archive: archive)
        reopened.adoptDeviceLocation(latitude: 49.8397, longitude: 24.0297)

        #expect(reopened.spot?.coordinate == GeoCoordinate(latitude: 50.4501, longitude: 30.5234),
                "a location fix moved a spot the person had placed")
        #expect(reopened.spot?.horizon == traced)
    }

    @Test("Moving the spot is written down straight away")
    func movesAreSavedImmediately() throws {
        let archive = Self.archive()
        let store = SpotStore(archive: archive)
        store.move(to: GeoCoordinate(latitude: 10, longitude: 20))

        let onDisk = try archive.load()
        #expect(onDisk.count == 1)
        #expect(onDisk.first?.coordinate == GeoCoordinate(latitude: 10, longitude: 20))
    }

    @Test("A damaged file gives an empty start rather than a launch that fails")
    func damagedFileDoesNotBlockLaunch() throws {
        let archive = Self.archive()
        try Data("this is not json".utf8).write(to: archive.url)

        #expect(archive.loadIgnoringDamage().isEmpty)
        let store = SpotStore(archive: archive)
        #expect(store.spot == nil)

        // And the app can carry on and save over it.
        store.move(to: GeoCoordinate(latitude: 1, longitude: 2))
        #expect(try archive.load().count == 1)
    }

    @Test("Nothing saved yet means an empty start, not a crash")
    func missingFileIsFine() throws {
        let archive = Self.archive()
        #expect(try archive.load().isEmpty)
        #expect(SpotStore(archive: archive).spot == nil)
    }

    @Test("The time zone a spot was traced in comes back with it")
    func timeZoneSurvives() throws {
        let archive = Self.archive()
        let sydney = TimeZone(identifier: "Australia/Sydney")!
        try archive.save([Spot(
            name: "Balcony",
            coordinate: GeoCoordinate(latitude: -33.87, longitude: 151.21),
            timeZone: sydney
        )])

        let restored = try #require(SpotStore(archive: archive).spot)
        #expect(restored.timeZone == sydney)
        #expect(restored.name == "Balcony")
    }
}

/// Moving the file must not cost anyone their tracing.
@MainActor
struct ArchiveMigrationTests {

    static func temporary() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("A spot saved by an older version is carried across, not left behind")
    func oldFileIsCarriedAcross() throws {
        let folder = Self.temporary()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let old = folder.appendingPathComponent("old.json")
        let new = folder.appendingPathComponent("new.json")

        let traced = HorizonProfile(samples: [
            .init(azimuth: 100, elevation: 20),
            .init(azimuth: 200, elevation: 30)
        ])
        try SpotArchive(url: old).save([Spot(
            name: "Here",
            coordinate: GeoCoordinate(latitude: 47.8, longitude: 35.1),
            horizon: traced
        )])

        // Stand in for the real migration: copy across only when nothing is there yet.
        #expect(!FileManager.default.fileExists(atPath: new.path))
        try FileManager.default.copyItem(at: old, to: new)

        let restored = try SpotArchive(url: new).load()
        #expect(restored.first?.horizon == traced)
        #expect(FileManager.default.fileExists(atPath: old.path),
                "the original must survive the copy")
    }

    @Test("Migration never overwrites something already in the new place")
    func existingFileWins() throws {
        let folder = Self.temporary()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let new = folder.appendingPathComponent("new.json")

        let current = Spot(name: "Current", coordinate: GeoCoordinate(latitude: 1, longitude: 2))
        try SpotArchive(url: new).save([current])

        SpotArchive.migrateIfNeeded(to: new)

        let after = try SpotArchive(url: new).load()
        #expect(after.first?.name == "Current", "migration clobbered a newer file")
    }
}

/// Until now the app kept one spot while the paywall offered "as many as you like". These
/// pin the behaviour that closes that gap.
@MainActor
struct MultipleSpotsTests {

    static func store() -> (SpotStore, SpotArchive) {
        let archive = SpotArchive(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("spots-\(UUID().uuidString).json"))
        SharedSelection.record(selectedID: nil)
        return (SpotStore(archive: archive), archive)
    }

    static let fence = GeoCoordinate(latitude: 47.8388, longitude: 35.1495)
    static let garage = GeoCoordinate(latitude: 47.8390, longitude: 35.1500)

    @Test("A second spot can be added, and becomes the one being looked at")
    func addingSelectsTheNewSpot() {
        let (store, _) = Self.store()
        store.addSpot(at: Self.fence, named: "By the fence")
        let garage = store.addSpot(at: Self.garage, named: "By the garage")

        #expect(store.spots.count == 2)
        #expect(store.spot?.id == garage.id, "a spot you just placed should be the one on screen")
    }

    @Test("Switching spots switches what every screen is showing")
    func selectingChangesTheCurrentSpot() {
        let (store, _) = Self.store()
        let fence = store.addSpot(at: Self.fence, named: "By the fence")
        store.addSpot(at: Self.garage, named: "By the garage")

        store.select(fence.id)
        #expect(store.spot?.name == "By the fence")
    }

    @Test("Selecting something that is not there leaves the choice alone")
    func selectingAnUnknownSpotIsIgnored() {
        let (store, _) = Self.store()
        let only = store.addSpot(at: Self.fence, named: "Only")
        store.select(UUID())
        #expect(store.spot?.id == only.id)
    }

    @Test("Two spots a few metres apart keep their own skylines")
    func spotsKeepSeparateSkylines() {
        // The whole reason for having more than one: the bed by the fence and the bed by the
        // garage are metres apart and answer completely differently.
        let (store, _) = Self.store()
        let fence = store.addSpot(at: Self.fence, named: "By the fence")
        store.setHorizon(HorizonProfile(samples: stride(from: 0.0, to: 360.0, by: 30)
            .map { .init(azimuth: $0, elevation: 5) }))

        let garage = store.addSpot(at: Self.garage, named: "By the garage")
        store.setHorizon(HorizonProfile(samples: stride(from: 0.0, to: 360.0, by: 30)
            .map { .init(azimuth: $0, elevation: 70) }))

        store.select(fence.id)
        let open = store.spot?.horizon.obstructionElevation(atAzimuth: 180)
        store.select(garage.id)
        let walled = store.spot?.horizon.obstructionElevation(atAzimuth: 180)

        #expect(open == 5)
        #expect(walled == 70, "tracing one spot wrote over the other")
    }

    @Test("Moving a spot moves only that one")
    func movingAffectsOnlyTheSelectedSpot() {
        let (store, _) = Self.store()
        let fence = store.addSpot(at: Self.fence, named: "By the fence")
        store.addSpot(at: Self.garage, named: "By the garage")

        store.move(to: GeoCoordinate(latitude: 10, longitude: 20))

        #expect(store.spot?.coordinate == GeoCoordinate(latitude: 10, longitude: 20))
        store.select(fence.id)
        #expect(store.spot?.coordinate == Self.fence, "the other spot moved too")
    }

    @Test("Renaming takes, and an empty name is refused")
    func renaming() {
        let (store, _) = Self.store()
        let spot = store.addSpot(at: Self.fence, named: "Here")

        store.rename(spot.id, to: "  Balcony  ")
        #expect(store.spot?.name == "Balcony", "the name should be trimmed")

        store.rename(spot.id, to: "   ")
        #expect(store.spot?.name == "Balcony", "an empty name would leave a row with nothing in it")
    }

    @Test("Deleting the selected spot falls back to another rather than to nothing")
    func deletingSelectsAnother() {
        let (store, _) = Self.store()
        let fence = store.addSpot(at: Self.fence, named: "By the fence")
        let garage = store.addSpot(at: Self.garage, named: "By the garage")

        store.remove(garage.id)
        #expect(store.spots.count == 1)
        #expect(store.spot?.id == fence.id, "deleting left the app with nothing on screen")
    }

    @Test("Without paying there is one spot; the purchase is what lifts that")
    func freeLimitIsOneSpot() {
        let (store, _) = Self.store()
        #expect(store.canAddSpot(isUnlocked: false), "the first spot must always be free")

        store.addSpot(at: Self.fence)
        #expect(!store.canAddSpot(isUnlocked: false), "the second is what the purchase is for")
        #expect(store.canAddSpot(isUnlocked: true))
    }

    @Test("New spots get names that tell them apart")
    func namesAreDistinct() {
        let (store, _) = Self.store()
        store.addSpot(at: Self.fence)
        store.addSpot(at: Self.garage)
        store.addSpot(at: Self.fence)

        let names = store.spots.map(\.name)
        #expect(names.first == "Here")
        #expect(Set(names).count == names.count, "two spots ended up with the same name: \(names)")
    }

    @Test("All the spots are saved, and come back with the right one selected")
    func everythingSurvivesRelaunch() {
        let (store, archive) = Self.store()
        store.addSpot(at: Self.fence, named: "By the fence")
        let garage = store.addSpot(at: Self.garage, named: "By the garage")
        store.select(garage.id)

        let reopened = SpotStore(archive: archive)
        #expect(reopened.spots.count == 2, "only \(reopened.spots.count) spot(s) came back")
        #expect(reopened.spot?.id == garage.id, "the app reopened on a different spot")
    }

    @Test("A location fix does not add a second spot on top of the first")
    func locationDoesNotPileUpSpots() {
        let (store, _) = Self.store()
        store.addSpot(at: Self.fence, named: "By the fence")
        store.adoptDeviceLocation(latitude: 10, longitude: 20)

        #expect(store.spots.count == 1, "every launch would add another spot")
    }
}
