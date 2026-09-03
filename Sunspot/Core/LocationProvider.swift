import CoreLocation
import Observation

/// Where the phone is, and whether it is allowed to say.
///
/// The sun's path depends on latitude far more than most people expect — an hour's drive
/// north changes the answer — so the app asks for a real fix rather than guessing from a
/// time zone. Until one arrives the rest of the app shows a chosen place instead of
/// pretending to know.
@MainActor
@Observable
final class LocationProvider: NSObject {

    /// What the app is able to tell the person right now.
    enum State: Equatable {
        /// Not asked yet.
        case idle
        /// Asked, waiting for the system or the person to answer.
        case requesting
        /// A usable fix.
        case located(latitude: Double, longitude: Double)
        /// The person said no, or the device will not report a position.
        case unavailable(reason: String)
    }

    private(set) var state: State = .idle

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Asks for permission if it has not been asked, and starts a single fix.
    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .requesting
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            state = .requesting
            manager.requestLocation()
        case .denied:
            state = .unavailable(reason: String(localized: "Location is off for Sunplot. Turn it on in Settings, or pick a spot on the map."))
        case .restricted:
            state = .unavailable(reason: String(localized: "This device does not allow location. Pick a spot on the map instead."))
        @unknown default:
            state = .unavailable(reason: String(localized: "Location is not available. Pick a spot on the map instead."))
        }
    }

    fileprivate func apply(latitude: Double, longitude: Double) {
        state = .located(latitude: latitude, longitude: longitude)
    }

    fileprivate func fail(_ reason: String) {
        // A refusal is worth reporting; a momentary failure to get a fix is not, because the
        // system will usually deliver one a moment later.
        if case .located = state { return }
        state = .unavailable(reason: reason)
    }
}

extension LocationProvider: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        Task { @MainActor [weak self] in
            self?.apply(latitude: latitude, longitude: longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let description = (error as? CLError)?.code == .denied
            ? String(localized: "Location is off for Sunplot. Turn it on in Settings, or pick a spot on the map.")
            : String(localized: "Could not get a position just now. Pick a spot on the map instead.")
        Task { @MainActor [weak self] in
            self?.fail(description)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.state = .requesting
                self.manager.requestLocation()
            case .denied:
                self.fail(String(localized: "Location is off for Sunplot. Turn it on in Settings, or pick a spot on the map."))
            case .restricted:
                self.fail(String(localized: "This device does not allow location. Pick a spot on the map instead."))
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}
