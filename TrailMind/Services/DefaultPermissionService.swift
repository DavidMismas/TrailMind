import Foundation
import Combine
import CoreLocation
import HealthKit
import CoreMotion
import UIKit

final class DefaultPermissionService: NSObject, PermissionService, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()
    private let subject = CurrentValueSubject<PermissionSnapshot, Never>(.empty)

    var snapshotPublisher: AnyPublisher<PermissionSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    override init() {
        super.init()
        locationManager.delegate = self
        refresh()
    }

    func refresh() {
        let locationStatus = locationManager.authorizationStatus

        let healthAuthorized: Bool
        if HKHealthStore.isHealthDataAvailable(),
           let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            healthAuthorized = healthStore.authorizationStatus(for: heartRateType) == .sharingAuthorized
        } else {
            healthAuthorized = false
        }

        let motionAuthorized: Bool
        if #available(iOS 11.0, *) {
            motionAuthorized = CMPedometer.authorizationStatus() == .authorized
        } else {
            motionAuthorized = false
        }

        subject.send(
            PermissionSnapshot(
                locationWhenInUse: locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways,
                locationAlways: locationStatus == .authorizedAlways,
                health: healthAuthorized,
                motion: motionAuthorized
            )
        )
    }

    func requestLocationWhenInUse() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestLocationAlways() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func requestHealth() {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        else {
            refresh()
            return
        }

        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }

    func requestMotion() {
        guard CMPedometer.isCadenceAvailable() else {
            refresh()
            return
        }

        pedometer.queryPedometerData(from: Date().addingTimeInterval(-60), to: Date()) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        refresh()
    }
}
