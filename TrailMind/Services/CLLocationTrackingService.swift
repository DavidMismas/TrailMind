import Foundation
import CoreLocation
import Combine

final class CLLocationTrackingService: NSObject, CLLocationManagerDelegate, LocationTrackingService {
    private let manager = CLLocationManager()
    private let subject = PassthroughSubject<LocationPoint, Never>()
    private var fallbackTimer: AnyCancellable?
    private var simulatedStep = 0
    private var didReceiveRealLocation = false

    var locationPublisher: AnyPublisher<LocationPoint, Never> {
        subject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        didReceiveRealLocation = false

        let status = manager.authorizationStatus
        if status == .notDetermined {
            startFallbackSimulation()
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            configureAndStartUpdates()
        } else {
            startFallbackSimulation()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        fallbackTimer?.cancel()
        fallbackTimer = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            configureAndStartUpdates()
        } else if status != .notDetermined {
            startFallbackSimulation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        didReceiveRealLocation = true
        stopFallbackSimulation()
        subject.send(LocationPoint(location: location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        startFallbackSimulation()
    }

    private func startFallbackSimulation() {
        guard !didReceiveRealLocation else { return }
        guard fallbackTimer == nil else { return }
        fallbackTimer = Timer.publish(every: 4, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                simulatedStep += 1
                let baseLat = 46.0569
                let baseLon = 14.5058
                let lat = baseLat + Double(simulatedStep) * 0.00008
                let lon = baseLon + Double(simulatedStep % 4) * 0.00005
                let altitude = 295 + sin(Double(simulatedStep) / 2) * 18
                let speed = 1.1 + Double(simulatedStep % 3) * 0.24
                // Simulate good vertical accuracy (approx 3-4 meters)
                let vertAcc = 3.0 + Double(simulatedStep % 2)
                let point = LocationPoint(
                    timestamp: date,
                    latitude: lat,
                    longitude: lon,
                    altitude: altitude,
                    speed: speed,
                    verticalAccuracy: vertAcc
                )
                subject.send(point)
            }
    }

    private func stopFallbackSimulation() {
        fallbackTimer?.cancel()
        fallbackTimer = nil
    }

    private func configureAndStartUpdates() {
        let status = manager.authorizationStatus
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        let supportsBackgroundLocation = backgroundModes?.contains("location") == true
        manager.allowsBackgroundLocationUpdates = supportsBackgroundLocation && (status == .authorizedAlways)
        manager.startUpdatingLocation()
    }
}
