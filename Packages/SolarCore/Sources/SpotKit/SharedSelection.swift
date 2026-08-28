import Foundation

/// Which spot the widget should be talking about.
///
/// Once there is more than one spot, "the first in the file" stops being an answer: somebody
/// with a bed by the fence and a bed by the garage would find the home screen quietly
/// reporting the wrong one. The app writes down which is in front of them; the widget reads it.
public enum SharedSelection {

    private static let key = "selectedSpotID"

    private static var store: UserDefaults? {
        UserDefaults(suiteName: SpotArchive.appGroup)
    }

    /// The spot the app was last showing, if it is still there.
    public static var selectedID: UUID? {
        guard let raw = store?.string(forKey: key) else { return nil }
        return UUID(uuidString: raw)
    }

    public static func record(selectedID: UUID?) {
        guard let store else { return }
        if let selectedID {
            store.set(selectedID.uuidString, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    /// Picks the spot to show from everything saved.
    public static func spot(from spots: [Spot]) -> Spot? {
        SunSnapshot.spot(from: spots, selectedID: selectedID)
    }
}
