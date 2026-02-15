import Foundation
import Combine

final class AdaptiveHeartRateService: HeartRateService, BluetoothHeartRateControlService {
    private let heartRateSubject = PassthroughSubject<Double, Never>()
    private let sourceSubject = CurrentValueSubject<String, Never>("No heart-rate source")
    private let preferredBLESubject: CurrentValueSubject<Bool, Never>
    private let bleStateSubject = CurrentValueSubject<BluetoothHeartRateConnectionState, Never>(.idle)

    private let healthKitService: HealthKitHeartRateService
    private let bluetoothService: BluetoothHeartRateService
    private let preferencesStore: HeartRatePreferencesStore

    private var cancellables = Set<AnyCancellable>()
    private var lastHealthKitSampleAt: Date?
    private let healthKitStaleAfter: TimeInterval = 14

    var heartRatePublisher: AnyPublisher<Double, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }

    var sourceLabelPublisher: AnyPublisher<String, Never> {
        sourceSubject.eraseToAnyPublisher()
    }

    var preferredBLEPublisher: AnyPublisher<Bool, Never> {
        preferredBLESubject.eraseToAnyPublisher()
    }

    var bleStatePublisher: AnyPublisher<BluetoothHeartRateConnectionState, Never> {
        bleStateSubject.eraseToAnyPublisher()
    }

    var isBLEPreferred: Bool {
        preferredBLESubject.value
    }

    init(
        healthKitService: HealthKitHeartRateService,
        bluetoothService: BluetoothHeartRateService = BluetoothHeartRateService(),
        preferencesStore: HeartRatePreferencesStore = HeartRatePreferencesStore()
    ) {
        self.healthKitService = healthKitService
        self.bluetoothService = bluetoothService
        self.preferencesStore = preferencesStore
        self.preferredBLESubject = CurrentValueSubject(preferencesStore.preferBLE)

        bindServices()
    }

    func start() {
        healthKitService.start()
        if isBLEPreferred {
            bluetoothService.connect()
        }
    }

    func stop() {
        healthKitService.stop()
    }

    func setBLEPreferred(_ enabled: Bool) {
        guard enabled != preferredBLESubject.value else { return }

        preferencesStore.preferBLE = enabled
        preferredBLESubject.send(enabled)

        if enabled {
            bluetoothService.connect()
            sourceSubject.send("BLE preferred")
        } else {
            sourceSubject.send("HealthKit preferred")
        }
    }

    func connectBLE() {
        bluetoothService.connect()
    }

    func disconnectBLE() {
        bluetoothService.disconnect()
        if isBLEPreferred {
            sourceSubject.send("BLE disconnected")
        }
    }

    private func bindServices() {
        healthKitService.heartRatePublisher
            .sink { [weak self] bpm in
                self?.consumeHealthKit(bpm)
            }
            .store(in: &cancellables)

        bluetoothService.heartRatePublisher
            .sink { [weak self] bpm in
                self?.consumeBLE(bpm)
            }
            .store(in: &cancellables)

        bluetoothService.statePublisher
            .sink { [weak self] state in
                guard let self else { return }
                bleStateSubject.send(state)

                if !isBLEPreferred, case .connected(_) = state {
                    sourceSubject.send("HealthKit preferred (BLE ready)")
                } else if isBLEPreferred {
                    switch state {
                    case .connected(let name):
                        sourceSubject.send("BLE \(name)")
                    case .scanning, .connecting(_):
                        sourceSubject.send("Waiting for BLE sensor")
                    case .unauthorized:
                        sourceSubject.send("BLE permission needed")
                    case .poweredOff:
                        sourceSubject.send("Bluetooth off")
                    case .unsupported:
                        sourceSubject.send("BLE unavailable")
                    case .idle, .failed(_):
                        sourceSubject.send("BLE not connected")
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func consumeHealthKit(_ bpm: Double) {
        lastHealthKitSampleAt = Date()

        if isBLEPreferred {
            if case .connected(_) = bleStateSubject.value {
                return
            }
        }

        sourceSubject.send("HealthKit")
        heartRateSubject.send(bpm)
    }

    private func consumeBLE(_ bpm: Double) {
        let shouldUseBLE = isBLEPreferred || isHealthKitStale
        guard shouldUseBLE else { return }

        if case .connected(let name) = bleStateSubject.value {
            sourceSubject.send("BLE \(name)")
        } else {
            sourceSubject.send("BLE sensor")
        }
        heartRateSubject.send(bpm)
    }

    private var isHealthKitStale: Bool {
        guard let lastHealthKitSampleAt else { return true }
        return Date().timeIntervalSince(lastHealthKitSampleAt) > healthKitStaleAfter
    }
}
