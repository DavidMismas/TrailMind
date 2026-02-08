import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var premiumTier: PremiumTier = .free
    @Published private(set) var isPurchasing = false
    @Published private(set) var purchaseStatus = ""

    @Published var locationEnabled = false
    @Published var backgroundLocationEnabled = false
    @Published var fitnessEnabled = false
    @Published var preferDirectBLE = false
    @Published private(set) var bleState: BluetoothHeartRateConnectionState = .idle

    private let premiumService: PremiumPurchaseService
    private let permissionService: PermissionService
    private let bluetoothHeartRateService: BluetoothHeartRateControlService
    private var cancellables = Set<AnyCancellable>()
    private var isSystemSyncing = false

    init(
        premiumService: PremiumPurchaseService,
        permissionService: PermissionService,
        bluetoothHeartRateService: BluetoothHeartRateControlService
    ) {
        self.premiumService = premiumService
        self.permissionService = permissionService
        self.bluetoothHeartRateService = bluetoothHeartRateService

        premiumService.tierPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tier in
                self?.premiumTier = tier
            }
            .store(in: &cancellables)

        permissionService.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                isSystemSyncing = true
                locationEnabled = snapshot.locationWhenInUse
                backgroundLocationEnabled = snapshot.locationAlways
                fitnessEnabled = snapshot.health || snapshot.motion
                isSystemSyncing = false
            }
            .store(in: &cancellables)

        bluetoothHeartRateService.preferredBLEPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] preferred in
                guard let self else { return }
                isSystemSyncing = true
                preferDirectBLE = preferred
                isSystemSyncing = false
            }
            .store(in: &cancellables)

        bluetoothHeartRateService.bleStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.bleState = state
            }
            .store(in: &cancellables)

        permissionService.refresh()
    }

    func purchasePremium() {
        guard !isPurchasing else { return }

        isPurchasing = true
        purchaseStatus = "Processing purchase..."

        Task {
            do {
                try await premiumService.purchaseLifetime()
                await MainActor.run {
                    isPurchasing = false
                    purchaseStatus = "Premium unlocked."
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    purchaseStatus = "Purchase failed. Try again."
                }
            }
        }
    }

    func locationToggleChanged(_ enabled: Bool) {
        guard !isSystemSyncing else { return }
        if enabled {
            permissionService.requestLocationWhenInUse()
        } else {
            permissionService.openSystemSettings()
        }
        permissionService.refresh()
    }

    func backgroundLocationToggleChanged(_ enabled: Bool) {
        guard !isSystemSyncing else { return }
        if enabled {
            permissionService.requestLocationAlways()
        } else {
            permissionService.openSystemSettings()
        }
        permissionService.refresh()
    }

    func fitnessToggleChanged(_ enabled: Bool) {
        guard !isSystemSyncing else { return }
        if enabled {
            permissionService.requestHealth()
            permissionService.requestMotion()
        } else {
            permissionService.openSystemSettings()
        }
        permissionService.refresh()
    }

    func openSystemSettings() {
        permissionService.openSystemSettings()
    }

    func preferDirectBLEChanged(_ enabled: Bool) {
        guard !isSystemSyncing else { return }
        bluetoothHeartRateService.setBLEPreferred(enabled)
    }

    func connectBLE() {
        bluetoothHeartRateService.connectBLE()
    }

    func disconnectBLE() {
        bluetoothHeartRateService.disconnectBLE()
    }

    var blePrimaryButtonTitle: String {
        switch bleState {
        case .scanning:
            return "Scanning..."
        case .connecting(_):
            return "Connecting..."
        case .connected(_):
            return "Reconnect"
        default:
            return "Connect Sensor"
        }
    }

    var canTapConnectBLE: Bool {
        switch bleState {
        case .scanning, .connecting(_):
            return false
        case .poweredOff, .unauthorized, .unsupported:
            return false
        default:
            return true
        }
    }
}
