import Foundation
import CoreBluetooth
import Combine

final class BluetoothHeartRateService: NSObject {
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")
    private let heartRateDeviceInfoUUID = CBUUID(string: "180A")
    private let deviceNameUUID = CBUUID(string: "2A00")

    private let heartRateSubject = PassthroughSubject<Double, Never>()
    private let stateSubject = CurrentValueSubject<BluetoothHeartRateConnectionState, Never>(.idle)

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var activeCandidatePeripheral: CBPeripheral?
    private var measurementCharacteristic: CBCharacteristic?
    private var scanTimeoutWorkItem: DispatchWorkItem?
    private var connectTimeoutWorkItem: DispatchWorkItem?
    private var shouldReconnect = false
    private var seenPeripheralIDs = Set<UUID>()
    private var candidatePeripherals: [CBPeripheral] = []

    var heartRatePublisher: AnyPublisher<Double, Never> {
        heartRateSubject.eraseToAnyPublisher()
    }

    var statePublisher: AnyPublisher<BluetoothHeartRateConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var connectedDeviceName: String? {
        if case .connected(let name) = stateSubject.value {
            return name
        }
        return nil
    }

    override init() {
        super.init()
    }

    func connect() {
        let central = manager
        shouldReconnect = true
        guard central.state == .poweredOn else {
            publishStateForCentralState()
            return
        }

        if let peripheral = connectedPeripheral, peripheral.state == .connected {
            discoverHeartRateCharacteristics(on: peripheral)
            publishConnectedState(for: peripheral)
            return
        }

        let currentlyConnected = central.retrieveConnectedPeripherals(withServices: [heartRateServiceUUID])
        if let knownHeartRatePeripheral = currentlyConnected.first {
            connect(to: knownHeartRatePeripheral)
            return
        }

        startScanning()
    }

    func disconnect() {
        shouldReconnect = false
        stopScanning()
        cancelConnectTimeout()
        candidatePeripherals.removeAll()
        activeCandidatePeripheral = nil
        measurementCharacteristic = nil

        guard let central = centralManager else {
            stateSubject.send(.idle)
            return
        }

        guard let peripheral = connectedPeripheral else {
            stateSubject.send(.idle)
            return
        }

        central.cancelPeripheralConnection(peripheral)
    }

    private func startScanning() {
        let central = manager
        guard central.state == .poweredOn else {
            publishStateForCentralState()
            return
        }
        guard !central.isScanning else { return }

        scanTimeoutWorkItem?.cancel()
        seenPeripheralIDs.removeAll()
        candidatePeripherals.removeAll()
        activeCandidatePeripheral = nil
        stateSubject.send(.scanning)

        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        let timeout = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.connectedPeripheral == nil else { return }
            guard self.activeCandidatePeripheral == nil else { return }
            self.stopScanning()
            self.stateSubject.send(.failed(reason: "No compatible BLE heart-rate device found."))
        }
        scanTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
    }

    private func stopScanning() {
        scanTimeoutWorkItem?.cancel()
        scanTimeoutWorkItem = nil
        if centralManager?.isScanning == true {
            centralManager?.stopScan()
        }
    }

    private func cancelConnectTimeout() {
        connectTimeoutWorkItem?.cancel()
        connectTimeoutWorkItem = nil
    }

    private func scheduleConnectTimeout(for peripheral: CBPeripheral) {
        cancelConnectTimeout()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.activeCandidatePeripheral?.identifier == peripheral.identifier else { return }
            self.stateSubject.send(.failed(reason: "Connection timed out for \(peripheral.displayName)."))
            self.activeCandidatePeripheral = nil
            self.manager.cancelPeripheralConnection(peripheral)
            self.connectNextCandidate()
        }
        connectTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)
    }

    private func discoverHeartRateCharacteristics(on peripheral: CBPeripheral) {
        if let service = peripheral.services?.first(where: { $0.uuid == heartRateServiceUUID }) {
            peripheral.discoverCharacteristics([heartRateMeasurementUUID], for: service)
        } else {
            peripheral.discoverServices([heartRateServiceUUID, heartRateDeviceInfoUUID])
        }
    }

    private func publishConnectedState(for peripheral: CBPeripheral) {
        stateSubject.send(.connected(name: peripheral.displayName))
    }

    private func parseHeartRate(_ data: Data) -> Double? {
        let bytes = [UInt8](data)
        guard bytes.count >= 2 else { return nil }

        let flags = bytes[0]
        let isUInt16 = (flags & 0x01) != 0

        if isUInt16 {
            guard bytes.count >= 3 else { return nil }
            let value = UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
            return Double(value)
        }

        return Double(bytes[1])
    }

    private func publishStateForCentralState() {
        guard let central = centralManager else {
            stateSubject.send(.idle)
            return
        }

        switch central.state {
        case .unsupported:
            stateSubject.send(.unsupported)
        case .unauthorized:
            stateSubject.send(.unauthorized)
        case .poweredOff:
            stateSubject.send(.poweredOff)
        case .poweredOn:
            if let peripheral = connectedPeripheral, peripheral.state == .connected {
                publishConnectedState(for: peripheral)
            } else if central.isScanning {
                stateSubject.send(.scanning)
            } else {
                stateSubject.send(.idle)
            }
        case .unknown, .resetting:
            stateSubject.send(.idle)
        @unknown default:
            stateSubject.send(.idle)
        }
    }

    private var manager: CBCentralManager {
        if let centralManager {
            return centralManager
        }
        let created = CBCentralManager(delegate: self, queue: .main)
        centralManager = created
        return created
    }

    private func isCandidatePeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
        if let connectableValue = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber,
           !connectableValue.boolValue {
            return false
        }

        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
           serviceUUIDs.contains(heartRateServiceUUID) {
            return true
        }

        if let overflowUUIDs = advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID],
           overflowUUIDs.contains(heartRateServiceUUID) {
            return true
        }

        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           serviceData.keys.contains(heartRateServiceUUID) {
            return true
        }

        if let rssi = advertisementData["kCBAdvDataRxPrimaryPHY"] as? NSNumber, rssi.intValue == 0 {
            return true
        }

        if peripheral.name != nil {
            return true
        }

        return true
    }

    private func enqueueCandidate(_ peripheral: CBPeripheral) {
        guard !candidatePeripherals.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        candidatePeripherals.append(peripheral)
    }

    private func connectNextCandidate() {
        guard connectedPeripheral == nil else { return }
        guard activeCandidatePeripheral == nil else { return }
        guard let central = centralManager else { return }
        guard central.state == .poweredOn else { return }

        guard let next = candidatePeripherals.first else {
            return
        }

        candidatePeripherals.removeFirst()
        connect(to: next)
    }

    private func connect(to peripheral: CBPeripheral) {
        guard let central = centralManager else { return }
        activeCandidatePeripheral = peripheral
        peripheral.delegate = self
        stateSubject.send(.connecting(name: peripheral.displayName))
        scheduleConnectTimeout(for: peripheral)
        central.connect(peripheral, options: nil)
    }
}

extension BluetoothHeartRateService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        publishStateForCentralState()

        guard shouldReconnect else { return }
        guard central.state == .poweredOn else { return }
        guard connectedPeripheral?.state != .connected else { return }

        startScanning()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard connectedPeripheral == nil else { return }
        guard !seenPeripheralIDs.contains(peripheral.identifier) else { return }
        seenPeripheralIDs.insert(peripheral.identifier)
        guard isCandidatePeripheral(peripheral, advertisementData: advertisementData) else { return }
        enqueueCandidate(peripheral)
        connectNextCandidate()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        cancelConnectTimeout()
        activeCandidatePeripheral = nil
        connectedPeripheral = peripheral
        peripheral.delegate = self
        publishConnectedState(for: peripheral)
        discoverHeartRateCharacteristics(on: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        cancelConnectTimeout()
        if activeCandidatePeripheral?.identifier == peripheral.identifier {
            activeCandidatePeripheral = nil
        }
        connectedPeripheral = nil
        measurementCharacteristic = nil
        stateSubject.send(.failed(reason: "BLE connection failed."))
        if shouldReconnect {
            connectNextCandidate()
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cancelConnectTimeout()
        if activeCandidatePeripheral?.identifier == peripheral.identifier {
            activeCandidatePeripheral = nil
        }
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
        measurementCharacteristic = nil

        if shouldReconnect {
            stateSubject.send(.idle)
            connectNextCandidate()
            startScanning()
        } else {
            stateSubject.send(.idle)
        }
    }
}

extension BluetoothHeartRateService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            stateSubject.send(.failed(reason: "Could not read BLE services."))
            manager.cancelPeripheralConnection(peripheral)
            return
        }

        guard let services = peripheral.services, !services.isEmpty else {
            stateSubject.send(.failed(reason: "Connected, but no BLE services were found."))
            manager.cancelPeripheralConnection(peripheral)
            return
        }

        let hasHeartRateService = services.contains { $0.uuid == heartRateServiceUUID }
        if !hasHeartRateService {
            stateSubject.send(
                .failed(
                    reason: "Connected to \(peripheral.displayName), but it does not expose standard BLE heart rate service (0x180D)."
                )
            )
            manager.cancelPeripheralConnection(peripheral)
            return
        }

        services.forEach { service in
            if service.uuid == heartRateServiceUUID {
                peripheral.discoverCharacteristics([heartRateMeasurementUUID], for: service)
            } else if service.uuid == heartRateDeviceInfoUUID {
                peripheral.discoverCharacteristics([deviceNameUUID], for: service)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            stateSubject.send(.failed(reason: "Could not read BLE characteristics."))
            manager.cancelPeripheralConnection(peripheral)
            return
        }

        if service.uuid == heartRateServiceUUID {
            let heartRateCharacteristic = service.characteristics?.first(where: { $0.uuid == heartRateMeasurementUUID })
            guard let heartRateCharacteristic else {
                stateSubject.send(
                    .failed(
                        reason: "Connected to \(peripheral.displayName), but heart-rate characteristic (0x2A37) is missing."
                    )
                )
                manager.cancelPeripheralConnection(peripheral)
                return
            }

            measurementCharacteristic = heartRateCharacteristic
            peripheral.setNotifyValue(true, for: heartRateCharacteristic)
            return
        }

        if service.uuid == heartRateDeviceInfoUUID,
           let nameCharacteristic = service.characteristics?.first(where: { $0.uuid == deviceNameUUID }) {
            peripheral.readValue(for: nameCharacteristic)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil else { return }

        if characteristic.uuid == heartRateMeasurementUUID,
           let data = characteristic.value,
           let bpm = parseHeartRate(data) {
            heartRateSubject.send(bpm)
            publishConnectedState(for: peripheral)
        }

        if characteristic.uuid == deviceNameUUID,
           let data = characteristic.value,
           let string = String(data: data, encoding: .utf8),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stateSubject.send(.connected(name: string.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
    }
}

private extension CBPeripheral {
    var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "BLE HR Device" : trimmed
    }
}
