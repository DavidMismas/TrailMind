import Foundation
import HealthKit
import WatchConnectivity
import SwiftUI
import Combine

@MainActor
class WatchViewModel: NSObject, ObservableObject, HKLiveWorkoutBuilderDelegate, HKWorkoutSessionDelegate, WCSessionDelegate {
    @Published var heartRate: Double = 0
    @Published var distance: Double = 0
    @Published var energy: Double = 0
    @Published var isTracking: Bool = false
    @Published var stateLabel: String = "Ready"
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    override init() {
        super.init()
        setupWCSession()
    }
    
    func start() {
        requestAuthorization { [weak self] success in
            guard success else { return }
            self?.startWorkout()
            self?.send(.startHike)
        }
    }
    
    func stop() {
        guard let workoutSession, let builder else { return }
        workoutSession.end()
        builder.endCollection(withEnd: Date()) { _, _ in
            builder.finishWorkout { _, _ in }
        }
        isTracking = false
        stateLabel = "Stopped"
        resetMetrics()
        resetMetrics()
        send(.stopHike)
    }
    
    private func resetMetrics() {
        heartRate = 0
        distance = 0
        energy = 0
    }
    
    // MARK: - HealthKit Setup
    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    private func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .hiking
        configuration.locationType = .outdoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = workoutSession?.associatedWorkoutBuilder()
            
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            workoutSession?.delegate = self
            builder?.delegate = self
            
            workoutSession?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { _, _ in }
            
            isTracking = true
            stateLabel = "Tracking"
            isTracking = true
            stateLabel = "Tracking"
            
        } catch {
            print("Failed to start workout: \(error)")
        }
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async { [weak self] in
                self?.updateMetrics(from: statistics)
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }
    
    private func updateMetrics(from statistics: HKStatistics?) {
        guard let statistics else { return }
        
        switch statistics.quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            let unit = HKUnit.count().unitDivided(by: .minute())
            let value = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
            heartRate = value
            sendHeartRateToPhone(value)
            
        case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
            let unit = HKUnit.meter()
            let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
            distance = value
            
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            let unit = HKUnit.kilocalorie()
            let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
            energy = value
            
        default:
            break
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Handle state changes
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session error: \(error)")
    }
    
    // MARK: - WatchConnectivity
    private func setupWCSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    private func send(_ command: WatchCommand) {
        guard WCSession.default.isReachable else { return }
        let message = ["command": command.rawValue]
        WCSession.default.sendMessage(message, replyHandler: nil)
    }
    
    // Kept for internal types, but we use WatchCommand now for logic
    enum WatchCommand: String {
        case startHike = "START"
        case stopHike = "STOP"
    }
    
    private func sendHeartRateToPhone(_ hr: Double) {
        guard WCSession.default.isReachable else { return }
        let message = ["heartRate": hr]
        WCSession.default.sendMessage(message, replyHandler: nil)
    }
    

    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Session activated
    }
    
    // Watch-only delegate methods
    #if os(watchOS)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from phone (e.g., start/stop command)
        DispatchQueue.main.async { [weak self] in
            if let commandString = message["command"] as? String,
               let command = WatchCommand(rawValue: commandString) {
                if command == .startHike {
                    self?.start()
                } else if command == .stopHike {
                    self?.stop()
                }
            }
        }
    }
    #endif
}
