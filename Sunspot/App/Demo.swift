import Foundation
import SwiftUI
import SolarCore
import SpotKit

/// Puts the app into one fixed, known state so the App Store screenshots can be shot without
/// touching the screen.
///
/// A set taken by hand drifts. A different spot every time, a skyline traced halfway in one
/// frame and not at all in the next, a figure nobody can reproduce a month later when the
/// store asks for a fresh set because a screen changed. Seeding the same garden every time
/// makes the whole folder disposable: delete it, run the script, get the same frames back.
///
/// Everything here is `#if DEBUG` and every part of it additionally waits to be asked for on
/// the command line. A release build carries none of the data, and a debug build launched
/// normally behaves as if this file were not here.
enum Demo {

    // MARK: - What was asked for

    /// The screen a screenshot run wants in front when the app opens.
    enum Screen: String {
        /// The four tabs.
        case today, map, sky, year
        /// Things reached from Today, which the run cannot tap its way to.
        case plants, compare, paywall
    }

    /// True while the app is being driven by the screenshot script.
    static var isRunning: Bool {
        #if DEBUG
        return arguments.contains("-SunspotDemoData")
        #else
        return false
        #endif
    }

    /// The screen to open on, or nil when nobody asked.
    static var screen: Screen? {
        #if DEBUG
        guard isRunning else { return nil }
        guard let index = arguments.firstIndex(of: "-SunspotDemoScreen"),
              index + 1 < arguments.count
        else { return .today }
        return Screen(rawValue: arguments[index + 1]) ?? .today
        #else
        return nil
        #endif
    }

    /// What the paywall is worth showing off, and what it is worth hiding.
    ///
    /// Every frame but one is shot with the purchase made, because a store listing shows the
    /// app rather than the shop. The paywall itself is the exception: it is shot locked, for
    /// the review screenshot the in-app purchase needs, and at the price the configuration
    /// file actually sells it for rather than one invented here.
    static var pretendedPurchase: PretendedPurchase? {
        #if DEBUG
        guard let screen else { return nil }
        return screen == .paywall ? .locked(price: "$5.99") : .unlocked
        #else
        return nil
        #endif
    }

    enum PretendedPurchase: Equatable {
        case unlocked
        case locked(price: String)
    }

    /// The moment every frame is shot at, in minutes after local midnight.
    ///
    /// Frozen on purpose. A run started at four in the morning would otherwise show a sun
    /// below the horizon and a day already spent, and the same run at noon would not — two
    /// sets that do not match, and neither of them saying anything about the app.
    static let momentOfDay = 13 * 60 + 30

    /// Where the Sky screen's camera is pointing for its frame, in degrees from true north,
    /// and how far above the horizontal.
    ///
    /// Just west of south, because that is where the sun stands in the early afternoon at
    /// every latitude this app is aimed at — and tipped up far enough that the sun sits in
    /// the top half of the frame with the traced skyline still in the bottom of it.
    static let skyBearing: Double = 190
    static let skyPitch: Double = 28

    // MARK: - Seeding

    /// Writes the demo garden into the shared container, before anything has read it.
    ///
    /// Called from the app's `init` rather than from a view: `SpotStore` loads the archive
    /// the moment it is built, and a seed written after that would be a file nobody opens.
    static func prepareIfRequested() {
        #if DEBUG
        guard isRunning else { return }
        let spots = spots()
        if let archive = try? SpotArchive() {
            try? archive.save(spots)
        }
        SharedSelection.record(selectedID: spots.first?.id)
        Unlock.record(isUnlocked: pretendedPurchase == .unlocked)
        #endif
    }

    #if DEBUG

    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    /// Fixed rather than random, so the widget's saved selection still names a spot that
    /// exists after the app is reinstalled between languages.
    private static let ids = [
        UUID(uuidString: "5C0DE000-0000-4000-A000-000000000001")!,
        UUID(uuidString: "5C0DE000-0000-4000-A000-000000000002")!,
        UUID(uuidString: "5C0DE000-0000-4000-A000-000000000003")!
    ]

    /// The three spots every frame is shot with: a garden bed that does well, a border by the
    /// house that does half as well, and a balcony that does not.
    ///
    /// Three rather than one, because half of what is being sold is the answer to "which of
    /// these is better", and a comparison of one spot is not a comparison. The figures they
    /// produce today are seven hours fifty, five and a half, and three and a quarter — far
    /// enough apart to be read at a glance, and none of them invented: they come out of the
    /// same engine as everybody else's, from the skylines below.
    static func spots() -> [Spot] {
        let place = place()
        let names = names()
        let skylines = [gardenSkyline, borderSkyline, balconySkyline]
        // Only the first is warned about. Three notifications for one garden is what makes
        // people turn all of them off.
        let alerts: [Int?] = [20, nil, nil]

        return (0..<3).map { index in
            Spot(
                id: ids[index],
                name: names[index],
                coordinate: place.spots[index],
                horizon: HorizonProfile(samples: skylines[index]),
                timeZone: place.timeZone,
                alertMinutesBefore: alerts[index]
            )
        }
    }

    private static func skyline(_ elevations: [Int]) -> [HorizonProfile.Sample] {
        zip(stride(from: 0.0, through: 350.0, by: 10), elevations)
            .map { HorizonProfile.Sample(azimuth: $0, elevation: Double($1)) }
    }

    /// A back garden: next door's tree to the east, the house to the west, and a two-storey
    /// terrace across the south that the midsummer sun clears easily and the December sun
    /// never does. Roughly what somebody actually traces, and the reason the answer is eight
    /// hours rather than the fourteen the sun is up for.
    private static let gardenSkyline = skyline([
        4, 4, 5, 6, 7, 10, 15, 20, 22, 24, 21, 17,      //   0°–110°  hedge, then the tree
        16, 15, 15, 16, 16, 16, 16, 16, 16, 17, 20, 23, // 120°–230°  the terrace opposite
        26, 28, 28, 26, 22, 17, 12, 9, 7, 5, 4, 4       // 240°–350°  the house
    ])

    /// The border on the other side of the same garden, tight against the wall. Everything
    /// stands a little higher from here, which is the whole point of the app: a few metres
    /// is the difference between eight hours and five and a half.
    private static let borderSkyline = skyline([
        8, 8, 11, 16, 22, 28, 34, 38, 40, 40, 38, 34,
        32, 31, 30, 30, 31, 31, 32, 33, 35, 37, 39, 41,
        42, 42, 42, 40, 35, 29, 22, 17, 13, 10, 8, 8
    ])

    /// A recessed balcony: walls either side and a slot of sky facing south. A few hours in
    /// the middle of the day and nothing at either end of it — and, because it is up above
    /// the rooftops, the only one of the three that still sees the sun in December.
    private static let balconySkyline = skyline([
        50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, //   0°–110°  the building behind
        50, 48, 40, 24, 12, 10, 12, 22, 38, 50, 50, 50, // 120°–230°  the slot
        50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50  // 240°–350°  the building again
    ])

    /// Where the demo garden is. Residential rather than a city centre, so the map frame
    /// shows gardens and rooftops instead of a railway station, and northern enough that the
    /// app is answering a question worth asking.
    private struct Place {
        let spots: [GeoCoordinate]
        let timeZone: TimeZone
    }

    private static func place() -> Place {
        switch language() {
        case "de":
            // Frohnau, a garden suburb of large plots. Two earlier tries put the pin beside a
            // motorway junction and then on a shopping street, both of which photograph as
            // exactly the sort of place nobody keeps a vegetable bed.
            Place(spots: [GeoCoordinate(latitude: 52.6335, longitude: 13.2790),
                          GeoCoordinate(latitude: 52.6332, longitude: 13.2797),
                          GeoCoordinate(latitude: 52.6340, longitude: 13.2801)],
                  timeZone: TimeZone(identifier: "Europe/Berlin") ?? .current)
        case "fr":
            // The park quarter of Maisons-Laffitte: villas on large plots, laid out in the
            // nineteenth century and still without a shop in it. Le Vésinet was tried first
            // and the pin landed on its high street, between a Monoprix and an optician.
            Place(spots: [GeoCoordinate(latitude: 48.9552, longitude: 2.1424),
                          GeoCoordinate(latitude: 48.9549, longitude: 2.1431),
                          GeoCoordinate(latitude: 48.9557, longitude: 2.1435)],
                  timeZone: TimeZone(identifier: "Europe/Paris") ?? .current)
        default:
            Place(spots: [GeoCoordinate(latitude: 51.5590, longitude: -0.1720),
                          GeoCoordinate(latitude: 51.5587, longitude: -0.1713),
                          GeoCoordinate(latitude: 51.5595, longitude: -0.1709)],
                  timeZone: TimeZone(identifier: "Europe/London") ?? .current)
        }
    }

    /// Spot names are the person's own words and so are never translated by the app. In a
    /// screenshot they are ours, and a German frame with an English label in the toolbar
    /// looks exactly like the half-translated app it is trying not to be.
    private static func names() -> [String] {
        switch language() {
        case "de": ["Beet hinterm Haus", "Streifen an der Wand", "Balkon"]
        case "fr": ["Planche du fond", "Bordure du mur", "Balcon"]
        default:   ["Back bed", "Wall border", "Balcony"]
        }
    }

    private static func language() -> String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    #endif
}

extension Demo.Screen: Identifiable {
    var id: String { rawValue }
}

extension View {
    /// Applies whatever the screenshot script asked for: the frozen moment, and the one
    /// screen a launch argument cannot reach because it is behind a tap.
    ///
    /// One modifier in one place rather than a flag in each screen. Outside a screenshot run
    /// — which is every run anybody but this script will ever do — it does nothing.
    func demoState() -> some View { modifier(DemoState()) }
}

private struct DemoState: ViewModifier {
    @Environment(SpotStore.self) private var store
    @State private var sheet: Demo.Screen?

    func body(content: Content) -> some View {
        content
            .task {
                guard Demo.isRunning else { return }
                // Every frame shot at the same time of day, so the set is one afternoon in
                // one garden rather than a scrapbook.
                store.scrub(toMinuteOfDay: Demo.momentOfDay)
                // Not `.plants`: that one is a push, and Today opens it from its own path.
                switch Demo.screen {
                case .compare, .paywall: sheet = Demo.screen
                default: break
                }
            }
            .sheet(item: $sheet) { screen in
                switch screen {
                case .compare:
                    CompareSpots()
                case .paywall:
                    Paywall()
                default:
                    EmptyView()
                }
            }
    }
}
