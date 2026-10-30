import CoreLocation
import Observation


@MainActor @Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    enum Status { case idle, locating, ready, denied, failed }

    private(set) var status: Status = .idle
    private(set) var location: ReportLocation?

    private let manager = CLLocationManager()
    
    private var timeoutTask: Task<Void, Never>?
    
    private let timeout: Duration = .seconds(10)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

   
    func request() {
        guard status != .locating else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .locating
            startTimeout()
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .denied
        default:
            status = .locating
            startTimeout()
            manager.requestLocation()
        }
    }

    
    func setManual(_ place: ReportLocation) {
        cancelTimeout()
        location = place
        status = .ready
    }

    

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
