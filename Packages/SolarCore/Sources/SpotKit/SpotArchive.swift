import Foundation
import SolarCore

/// Keeps the spot and its traced skyline on disk between launches.
///
/// Tracing a skyline is the one piece of real work this app asks of anyone: standing in the
/// right place, holding the phone up, drawing round the roofs and the trees. Losing that
/// when the system reclaims the app would be unforgivable, and it is the sort of loss people
/// discover a week later.
public struct SpotArchive {

    /// The container the app and the widget both see.
    public static let appGroup = "group.app.sunspot"

    /// Where the file lives now: inside the shared container, because the widget has to read
    /// it too and an app's own Application Support folder is invisible from outside.
    public static func defaultURL() throws -> URL {
        guard let shared = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        ) else {
            // No group — an older build, or a misconfigured one. Fall back rather than fail:
            // the app still works, only the widget goes quiet.
            return try applicationSupportURL()
        }
        let url = shared.appendingPathComponent("spots.json")
        migrateIfNeeded(to: url)
        return url
    }

    /// Where it used to live.
    public static func applicationSupportURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent("spots.json")
    }

    /// Carries a spot traced under an earlier version into the shared container.
    ///
    /// Somebody who has already stood in their garden and drawn round the rooftops should not
    /// have to do it again because the file moved house.
    public static func migrateIfNeeded(to destination: URL) {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path),
              let old = try? applicationSupportURL(),
              manager.fileExists(atPath: old.path)
        else { return }

        // Copied rather than moved: if anything goes wrong the original is still there.
        try? manager.copyItem(at: old, to: destination)
    }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public init() throws {
        self.url = try Self.defaultURL()
    }

    public func save(_ spots: [Spot]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(spots)
        // Written whole, so a crash midway leaves the previous file rather than half of a
        // new one.
        try data.write(to: url, options: .atomic)
    }

    public func load() throws -> [Spot] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Spot].self, from: data)
    }

    /// Reads what is there, and returns nothing rather than throwing if the file is damaged.
    ///
    /// A corrupt file is a bad day; a launch that fails because of one is a worse day.
    public func loadIgnoringDamage() -> [Spot] {
        (try? load()) ?? []
    }
}
