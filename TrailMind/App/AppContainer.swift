import Foundation
import SwiftData

final class AppContainer {
    let sessionStore: HikeSessionStore

    private let locationService = CLLocationTrackingService()
    private let heartRateService = HealthKitHeartRateService()
    private let cadenceService = MotionCadenceService()
    private let batteryService = DeviceBatteryMonitorService()
    private let fatigueService = DefaultFatigueScoringService()
    private let terrainService = DefaultTerrainInsightService()
    private let safetyService = DefaultSafetyEvaluationService()
    private let aiService = AppleIntelligenceNarratorService()
    private let postHikeService = DefaultPostHikeAnalysisService()
    private let cacheService = FileTrailCacheService()
    private let premiumService = DefaultPremiumPurchaseService()
    private let permissionService = DefaultPermissionService()
    private let gpxService = DefaultGPXExportService()

    init(modelContext: ModelContext) {
        let persistence = SwiftDataHikePersistenceService(context: modelContext)
        self.sessionStore = HikeSessionStore(persistence: persistence)
    }

    lazy var liveHikeViewModel = LiveHikeViewModel(
        sessionStore: sessionStore,
        locationService: locationService,
        heartRateService: heartRateService,
        cadenceService: cadenceService,
        batteryService: batteryService,
        fatigueService: fatigueService,
        terrainService: terrainService,
        safetyService: safetyService,
        aiService: aiService,
        cacheService: cacheService,
        premiumService: premiumService
    )

    lazy var postHikeViewModel = PostHikeViewModel(
        sessionStore: sessionStore,
        analysisService: postHikeService,
        gpxService: gpxService,
        premiumService: premiumService
    )

    lazy var settingsViewModel = SettingsViewModel(
        premiumService: premiumService,
        permissionService: permissionService
    )
}
