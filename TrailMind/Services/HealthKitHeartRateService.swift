import Foundation
import HealthKit
import Combine
import WatchConnectivity



final class HealthKitHeartRateService: NSObject, HeartRateService {
    private let subject = PassthroughSubject<Double, Never>()
    private let sourceSubject = CurrentValueSubject<String, Never>("HealthKit")
    private let healthStore = HKHealthStore()
    private var activeQuery: HKAnchoredObjectQuery?
    private let watchConnectivityService: WatchConnectivityService
    private var cancellables = Set<AnyCancellable>()

    init(watchConnectivityService: WatchConnectivityService) {
        self.watchConnectivityService = watchConnectivityService
        super.init()
        bindWatchConnectivity()
    }

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
            
            // Enable background delivery for heart rate updates
            self.healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
                if let error {
                    print("[HealthKit] Failed to enable background delivery: \(error.localizedDescription)")
                } else {
                    print("[HealthKit] Background delivery enabled: \(success)")
                }
            }
            
            
            self.startHeartRateQuery(type: heartRateType)
        }
        

    }
    
    private func bindWatchConnectivity() {
        watchConnectivityService.heartRatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heartRate in
                self?.subject.send(heartRate)
                self?.sourceSubject.send("Apple Watch (Live)")
            }
            .store(in: &cancellables)
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

