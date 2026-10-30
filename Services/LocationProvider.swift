import CoreLocation
import Observation

/// One-shot "where am I?" helper. Requires `NSLocationWhenInUseUsageDescription` in Info.plist.
///
/// Includes a 10-second timeout so the UI never hangs forever — important on
/// the Simulator, where `requestLocation()` may never call back because there
/// is no real GPS fix to return.
@MainActor @Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    enum Status { case idle, locating, ready, denied, failed }

    private(set) var status: Status = .idle
    private(set) var location: ReportLocation?

    private let manager = CLLocationManager()
    /// Cancelled when a fix arrives, fails, or the user changes auth.
    private var timeoutTask: Task<Void, Never>?
    /// How long to wait for a fix before giving up.
    private let timeout: Duration = .seconds(10)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// Asks for permission if needed, then fetches a single fix.
    func request() {
        guard status != .locating else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .locating
            startTimeout()
            manager.requestWhenInUseAuthorization()   // continues in locationManagerDidChangeAuthorization
        case .denied, .restricted:
            status = .denied
        default:
            status = .locating
            startTimeout()
            manager.requestLocation()
        }
    }

    /// Lets the user (or a test) supply a location manually — used when GPS is
    /// unavailable (e.g. the Simulator) and the user picks a spot on the map.
    func setManual(_ place: ReportLocation) {
        cancelTimeout()
        location = place
        status = .ready
    }

    // MARK: - CLLocationManagerDelegate (called off the main actor)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        Task { @MainActor in self.authorizationChanged(auth) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let fix = ReportLocation(latitude: last.coordinate.latitude,
                                 longitude: last.coordinate.longitude,
                                 accuracy: last.horizontalAccuracy)
        Task { @MainActor in
            self.location = fix
            self.status = .ready
            self.cancelTimeout()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denied = (error as? CLError)?.code == .denied
        Task { @MainActor in
            self.cancelTimeout()
            self.status = denied ? .denied : .failed
        }
    }

    // MARK: - Private

    private func authorizationChanged(_ auth: CLAuthorizationStatus) {
        guard status == .locating else { return }     // ignore the callback fired at start-up
        switch auth {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted:
            cancelTimeout()
            status = .denied
        default: break
        }
    }

    private func startTimeout() {
        cancelTimeout()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled, let self else { return }
            // Still locating after the timeout — give up gracefully.
            if self.status == .locating {
                self.status = .failed
            }
        }
    }

    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}
