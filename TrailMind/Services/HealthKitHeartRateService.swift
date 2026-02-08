import Foundation
import HealthKit
import Combine

final class HealthKitHeartRateService: HeartRateService {
    private let subject = PassthroughSubject<Double, Never>()
    private let sourceSubject = CurrentValueSubject<String, Never>("HealthKit")
    private let healthStore = HKHealthStore()
    private var activeQuery: HKAnchoredObjectQuery?

    var heartRatePublisher: AnyPublisher<Double, Never> {
        subject.eraseToAnyPublisher()
    }

    var sourceLabelPublisher: AnyPublisher<String, Never> {
        sourceSubject.eraseToAnyPublisher()
    }

    func start() {
        stop()

        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        else {
            return
        }

        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { [weak self] granted, _ in
            guard let self, granted else { return }
            self.startHeartRateQuery(type: heartRateType)
        }
    }

    func stop() {
        if let activeQuery {
            healthStore.stop(activeQuery)
        }
        activeQuery = nil
    }

    private func startHeartRateQuery(type: HKQuantityType) {
        let startDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            self?.publish(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.publish(samples)
        }

        activeQuery = query
        healthStore.execute(query)
    }

    private func publish(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.last
        else {
            return
        }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = latest.quantity.doubleValue(for: unit)
        DispatchQueue.main.async { [weak self] in
            self?.subject.send(bpm)
        }
    }
}
