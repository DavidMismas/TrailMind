import Foundation
import Combine
import UIKit

final class DeviceBatteryMonitorService: BatteryMonitoringService {
    private let subject = CurrentValueSubject<Double, Never>(1)
    private var timer: AnyCancellable?

    var batteryPublisher: AnyPublisher<Double, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        subject.send(readBattery())
        timer = Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.subject.send(self?.readBattery() ?? 1)
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    private func readBattery() -> Double {
        let rawLevel = UIDevice.current.batteryLevel
        if rawLevel < 0 { return 1 }
        return Double(rawLevel)
    }
}
