import Foundation
import Combine

protocol LocationTrackingService: AnyObject {
    var locationPublisher: AnyPublisher<LocationPoint, Never> { get }
    func start()
    func stop()
}

protocol HeartRateService: AnyObject {
    var heartRatePublisher: AnyPublisher<Double, Never> { get }
    func start()
    func stop()
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
    func liveInsight(from snapshot: LiveMetricsSnapshot) async -> String
}

protocol PostHikeAnalysisService {
    func buildReport(from session: HikeSession, historicalSessions: [HikeSession]) -> PostHikeReport
}

protocol OfflineTrailCacheService {
    func cache(route: [LocationPoint], sessionID: UUID)
    func load(sessionID: UUID) -> [LocationPoint]
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
