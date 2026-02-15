import Foundation
import WatchConnectivity
import Combine

final class DefaultWatchConnectivityService: NSObject, WatchConnectivityService, WCSessionDelegate {
    private let heartRateSubject = PassthroughSubject<Double, Never>()
    private let commandSubject = PassthroughSubject<WatchCommand, Never>()
    private let isReachableSubject = CurrentValueSubject<Bool, Never>(false)
    
    var heartRatePublisher: AnyPublisher<Double, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }
    
    var commandPublisher: AnyPublisher<WatchCommand, Never> {
        commandSubject.eraseToAnyPublisher()
    }
    
    var isReachablePublisher: AnyPublisher<Bool, Never> {
        isReachableSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
    }
    
    func start() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func send(_ command: WatchCommand) {
        guard WCSession.default.isReachable else { return }
        let message = ["command": command.rawValue]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("[WatchConnectivity] Failed to send command: \(error.localizedDescription)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachableSubject.send(session.isReachable)
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachableSubject.send(session.isReachable)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            // Handle Heart Rate
            if let heartRate = message["heartRate"] as? Double {
                self.heartRateSubject.send(heartRate)
            }
            
            // Handle Commands (e.g. from Watch to Phone)
            if let commandString = message["command"] as? String,
               let command = WatchCommand(rawValue: commandString) {
                self.commandSubject.send(command)
            }
            
            // Handle State (e.g. isRunning status)
            if let isRunning = message["watchWorkoutState"] as? Bool {
                 // For now, we might infer START/STOP from this if needed, 
                 // but explicit commands are cleaner.
                 // We can map this to a command if we want strict sync
                 if isRunning {
                     self.commandSubject.send(.startHike)
                 } else {
                     self.commandSubject.send(.stopHike)
                 }
            }
        }
    }
}
