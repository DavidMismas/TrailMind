import Foundation
import Combine

protocol LocationTrackingService: AnyObject {
    var locationPublisher: AnyPublisher<LocationPoint, Never> { get }
    func start()
    func stop()
}

protocol HeartRateService: AnyObject {
    var heartRatePublisher: AnyPublisher<Double, Never> { get }
    var sourceLabelPublisher: AnyPublisher<String, Never> { get }
    func start()
    func stop()
}

enum BluetoothHeartRateConnectionState: Equatable {
    case unsupported
    case unauthorized
    case poweredOff
    case idle
    case scanning
    case connecting(name: String)
    case connected(name: String)
    case failed(reason: String)

    var title: String {
        switch self {
        case .unsupported:
            return "Bluetooth LE unavailable on this device."
        case .unauthorized:
            return "Bluetooth permission is not granted."
        case .poweredOff:
            return "Bluetooth is powered off."
        case .idle:
            return "No BLE heart-rate device connected."
        case .scanning:
            return "Scanning for BLE heart-rate devices..."
        case .connecting(let name):
            return "Connecting to \(name)..."
        case .connected(let name):
            return "Connected to \(name)."
        case .failed(let reason):
            return reason
        }
    }

    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

protocol BluetoothHeartRateControlService: AnyObject {
    var preferredBLEPublisher: AnyPublisher<Bool, Never> { get }
    var bleStatePublisher: AnyPublisher<BluetoothHeartRateConnectionState, Never> { get }
    var isBLEPreferred: Bool { get }
    func setBLEPreferred(_ enabled: Bool)
    func connectBLE()
    func disconnectBLE()
}

protocol CadenceService: AnyObject {
    var cadencePublisher: AnyPublisher<Double, Never> { get }
    func start()
    func stop()
}

protocol BatteryMonitoringService: AnyObject {
    var batteryPublisher: AnyPublisher<Double, Never> { get }
    func start()
    func stop()
}

protocol FatigueScoringService {
    func evaluate(
        previous: FatigueState,
        elapsed: TimeInterval,
        speed: Double,
        slopePercent: Double,
        heartRate: Double,
        cadence: Double
    ) -> FatigueState
}

struct TerrainInsight {
    let terrain: TerrainType
    let pacingAdvice: String
    let safetyHint: String
}

protocol TerrainInsightService {
    func insight(speed: Double, slopePercent: Double, cadence: Double) -> TerrainInsight
}

protocol SafetyEvaluationService {
    func evaluate(
        fatigue: FatigueState,
        batteryLevel: Double,
        lastCheckIn: Date,
        elapsed: TimeInterval
    ) -> SafetyState
}

protocol AppleIntelligenceService {
    func liveInsight(from snapshot: LiveMetricsSnapshot, profile: UserProfile?) async -> String
    func postHikeInsights(
        for session: HikeSession,
        historicalSessions: [HikeSession],
        profile: UserProfile?
    ) async -> [PerformanceInsight]?
}

struct LiveAltitudeSample: Codable, Hashable {
    let distanceMeters: Double
    let altitudeMeters: Double
}

protocol LiveActivityService {
    func start(
        startedAt: Date,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentAltitudeMeters: Double,
        elevationGainMeters: Double,
        altitudeSamples: [LiveAltitudeSample]
    )
    func update(
        startedAt: Date,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentAltitudeMeters: Double,
        elevationGainMeters: Double,
        altitudeSamples: [LiveAltitudeSample]
    )
    func stop(
        startedAt: Date,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentAltitudeMeters: Double,
        elevationGainMeters: Double,
        altitudeSamples: [LiveAltitudeSample]
    )
}

protocol PostHikeAnalysisService {
    func buildReport(from session: HikeSession, historicalSessions: [HikeSession]) -> PostHikeReport
}

protocol OfflineTrailCacheService {
    func cache(route: [LocationPoint], sessionID: UUID)
    func load(sessionID: UUID) -> [LocationPoint]
}

protocol ActiveHikeStatePersistenceService {
    func save(_ checkpoint: ActiveHikeCheckpoint)
    func load() -> ActiveHikeCheckpoint?
    func clear()
}

protocol PremiumPurchaseService: AnyObject {
    var tierPublisher: AnyPublisher<PremiumTier, Never> { get }
    var currentTier: PremiumTier { get }
    func purchaseLifetime() async throws
}

protocol HikePersistenceService {
    func loadSessions() -> [HikeSession]
    func save(session: HikeSession)
    func rename(sessionID: UUID, newName: String)
}

protocol GPXExportService {
    func export(session: HikeSession) throws -> URL
}

struct PermissionSnapshot {
    var locationWhenInUse: Bool
    var locationAlways: Bool
    var health: Bool
    var motion: Bool

    static let empty = PermissionSnapshot(
        locationWhenInUse: false,
        locationAlways: false,
        health: false,
        motion: false
    )
}

protocol PermissionService: AnyObject {
    var snapshotPublisher: AnyPublisher<PermissionSnapshot, Never> { get }
    func refresh()
    func requestLocationWhenInUse()
    func requestLocationAlways()
    func requestHealth()
    func requestMotion()
    func openSystemSettings()
}
