import Foundation
import HealthKit
import Combine

final class HealthKitHeartRateService: HeartRateService {
    private let subject = PassthroughSubject<Double, Never>()
    private let healthStore = HKHealthStore()
    private var fallbackTimer: AnyCancellable?

    var heartRatePublisher: AnyPublisher<Double, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        else {
            startFallbackFeed()
            return
        }

        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { [weak self] granted, _ in
            guard let self else { return }
            if granted {
                self.startFallbackFeed()
            } else {
                self.startFallbackFeed()
            }
        }
    }

    func stop() {
        fallbackTimer?.cancel()
        fallbackTimer = nil
    }

    private func startFallbackFeed() {
        guard fallbackTimer == nil else { return }
        fallbackTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                let hr = 105 + Double(Int.random(in: 0...55))
                self?.subject.send(hr)
            }
    }
}
