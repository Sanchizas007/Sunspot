import Foundation
import SolarCore

/// Keeps the spot and its traced skyline on disk between launches.
///
/// Tracing a skyline is the one piece of real work this app asks of anyone: standing in the
/// right place, holding the phone up, drawing round the roofs and the trees. Losing that
/// when the system reclaims the app would be unforgivable, and it is the sort of loss people
/// discover a week later.
struct SpotArchive {

    /// Where the file lives. Application Support rather than Documents: this is the app's
    /// own record, not a document the person manages.
    static func defaultURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent("spots.json", conformingTo: .json)
    }

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init() throws {
        self.url = try Self.defaultURL()
    }

    func save(_ spots: [Spot]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(spots)
        // Written whole, so a crash midway leaves the previous file rather than half of a
        // new one.
        try data.write(to: url, options: .atomic)
    }

    func load() throws -> [Spot] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Spot].self, from: data)
    }

    /// Reads what is there, and returns nothing rather than throwing if the file is damaged.
    ///
    /// A corrupt file is a bad day; a launch that fails because of one is a worse day.
    func loadIgnoringDamage() -> [Spot] {
        (try? load()) ?? []
    }
}
