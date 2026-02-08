import Foundation
import CoreMotion
import Combine

final class MotionCadenceService: CadenceService {
    private let subject = PassthroughSubject<Double, Never>()
    private let pedometer = CMPedometer()
    private var fallbackTimer: AnyCancellable?

    var cadencePublisher: AnyPublisher<Double, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        if CMPedometer.isCadenceAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                if let cadence = data?.currentCadence?.doubleValue {
                    self?.subject.send(cadence)
                }
            }
        } else {
            startFallbackFeed()
        }
    }

    func stop() {
        pedometer.stopUpdates()
        fallbackTimer?.cancel()
        fallbackTimer = nil
    }

    private func startFallbackFeed() {
        guard fallbackTimer == nil else { return }
        fallbackTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.subject.send(Double.random(in: 1.2...1.9))
            }
    }
}
