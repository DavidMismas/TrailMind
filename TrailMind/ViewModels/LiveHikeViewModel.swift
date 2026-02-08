import Foundation
import CoreLocation
import Combine
import UIKit

@MainActor
final class LiveHikeViewModel: ObservableObject {
    @Published private(set) var route: [LocationPoint] = []
    @Published private(set) var segments: [TrailSegment] = []
    @Published private(set) var fatigueState: FatigueState = .initial
    @Published private(set) var safetyState: SafetyState = .calm
    @Published private(set) var heartRate: Double?
    @Published private(set) var heartRateSourceLabel: String = "No heart-rate source"
    @Published private(set) var cadence: Double = 0
    @Published private(set) var speed: Double = 0
    @Published private(set) var slopePercent: Double = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var batteryLevel: Double = 1
    @Published private(set) var terrain: TerrainType = .flat
    @Published private(set) var pacingAdvice: String = "Start moving to get pacing guidance."
    @Published private(set) var terrainSafetyHint: String = ""
    @Published private(set) var aiInsight: String = "Apple Intelligence insights appear during active tracking."
    @Published private(set) var isTracking = false
    @Published private(set) var premiumTier: PremiumTier = .free
    @Published private(set) var currentAltitude: Double = 0

    private let sessionStore: HikeSessionStore
    private let locationService: LocationTrackingService
    private let heartRateService: HeartRateService
    private let cadenceService: CadenceService
    private let batteryService: BatteryMonitoringService
    private let fatigueService: FatigueScoringService
    private let terrainService: TerrainInsightService
    private let safetyService: SafetyEvaluationService
    private let aiService: AppleIntelligenceService
    private let cacheService: OfflineTrailCacheService
    private let activeHikeStore: ActiveHikeStatePersistenceService
    private let profileStore: UserProfileStore

    private var startDate: Date?
    private var lastCheckIn = Date()
    private var lastPoint: LocationPoint?
    private var clockTicker: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var lastAIRequestAt: Date?
    private var lastHeartRateSampleAt: Date?
    private var lastCheckpointSavedAt: Date?

    private let maxInMemoryRoutePoints = 4000
    private let maxInMemorySegments = 6000
    private let memoryWarningRoutePoints = 1500
    private let memoryWarningSegments = 2200
    private let heartRateStaleAfter: TimeInterval = 25
    private let checkpointSaveInterval: TimeInterval = 4

    init(
        sessionStore: HikeSessionStore,
        locationService: LocationTrackingService,
        heartRateService: HeartRateService,
        cadenceService: CadenceService,
        batteryService: BatteryMonitoringService,
        fatigueService: FatigueScoringService,
        terrainService: TerrainInsightService,
        safetyService: SafetyEvaluationService,
        aiService: AppleIntelligenceService,
        cacheService: OfflineTrailCacheService,
        activeHikeStore: ActiveHikeStatePersistenceService,
        premiumService: PremiumPurchaseService,
        profileStore: UserProfileStore
    ) {
        self.sessionStore = sessionStore
        self.locationService = locationService
        self.heartRateService = heartRateService
        self.cadenceService = cadenceService
        self.batteryService = batteryService
        self.fatigueService = fatigueService
        self.terrainService = terrainService
        self.safetyService = safetyService
        self.aiService = aiService
        self.cacheService = cacheService
        self.activeHikeStore = activeHikeStore
        self.profileStore = profileStore

        locationService.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] point in
                self?.consume(point)
            }
            .store(in: &cancellables)

        heartRateService.heartRatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heartRate in
                self?.heartRate = heartRate
                self?.lastHeartRateSampleAt = Date()
            }
            .store(in: &cancellables)

        heartRateService.sourceLabelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] label in
                self?.heartRateSourceLabel = label
            }
            .store(in: &cancellables)

        cadenceService.cadencePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cadence in
                self?.cadence = cadence
            }
            .store(in: &cancellables)

        batteryService.batteryPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] battery in
                guard let self else { return }
                batteryLevel = battery
                refreshSafety()
            }
            .store(in: &cancellables)

        premiumService.tierPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tier in
                self?.premiumTier = tier
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMemoryPressure()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.persistCheckpoint(force: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.persistCheckpoint(force: true)
            }
            .store(in: &cancellables)

        restoreActiveHikeIfNeeded()
    }

    var energyToGoalText: String {
        guard isTracking else { return "Start tracking to estimate energy." }
        guard premiumTier.hasEnergyPrediction else { return "Premium unlocks energy-to-goal prediction." }

        if fatigueState.energyRemaining > 0.55 {
            return "Likely enough energy for the current route."
        }
        if fatigueState.energyRemaining > 0.3 {
            return "Energy is moderate. Plan a short break soon."
        }
        return "Energy is low. Consider turning back early."
    }

    var heartRateDisplayValue: String {
        if let heartRate {
            return "\(Int(heartRate.rounded())) bpm"
        }
        return "--"
    }

    var heartRateFootnote: String {
        heartRate == nil ? "Heart rate unavailable" : heartRateSourceLabel
    }

    var totalElevationGain: Double {
        segments.reduce(0) { $0 + max(0, $1.elevationGain) }
    }

    var totalDistance: Double {
        segments.reduce(0) { $0 + $1.distance }
    }

    var trailDifficultyScore: Double {
        guard !segments.isEmpty else { return 0 }
        let avg = segments.map(\.effortIndex).reduce(0, +) / Double(segments.count)
        return min(100, avg / 2)
    }

    func startHike() {
        guard !isTracking else { return }

        activeHikeStore.clear()
        isTracking = true
        startDate = Date()
        lastCheckIn = Date()
        elapsed = 0
        route.removeAll()
        segments.removeAll()
        fatigueState = .initial
        safetyState = .calm
        terrain = .flat
        pacingAdvice = "Start moving to get pacing guidance."
        terrainSafetyHint = ""
        aiInsight = "Collecting data..."
        lastPoint = nil
        heartRate = nil
        heartRateSourceLabel = "Waiting for heart-rate source"
        lastHeartRateSampleAt = nil
        lastCheckpointSavedAt = nil
        currentAltitude = 0

        startLiveServices()
        persistCheckpoint(force: true)
    }

    func stopHike() {
        guard isTracking, let startDate else { return }

        isTracking = false
        stopLiveServices()
        heartRate = nil
        heartRateSourceLabel = "No heart-rate source"
        lastHeartRateSampleAt = nil
        lastCheckpointSavedAt = nil

        let session = HikeSession(
            startedAt: startDate,
            endedAt: Date(),
            route: route,
            segments: segments,
            finalFatigue: fatigueState,
            finalSafety: safetyState
        )
        sessionStore.add(session)
        cacheService.cache(route: route, sessionID: session.id)
        activeHikeStore.clear()
    }

    func markSafetyCheckIn() {
        lastCheckIn = Date()
        refreshSafety()
        persistCheckpoint(force: true)
    }

    private func consume(_ point: LocationPoint) {
        guard isTracking else { return }

        currentAltitude = point.altitude

        route.append(point)
        if route.count > maxInMemoryRoutePoints {
            route = MemorySafeCollections.downsampleRoute(route, to: maxInMemoryRoutePoints)
        }

        guard let previous = lastPoint else {
            lastPoint = point
            persistCheckpoint(force: false)
            return
        }

        let distance = CLLocation(
            latitude: previous.coordinate.latitude,
            longitude: previous.coordinate.longitude
        ).distance(
            from: CLLocation(
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude
            )
        )

        let time = max(1, point.timestamp.timeIntervalSince(previous.timestamp))
        let segmentSpeed = distance / time
        let elevationGain = point.altitude - previous.altitude
        let slope = distance > 0 ? (elevationGain / distance) * 100 : 0

        speed = segmentSpeed
        slopePercent = slope

        let terrainInsight = terrainService.insight(speed: segmentSpeed, slopePercent: slope, cadence: cadence)
        terrain = terrainInsight.terrain
        pacingAdvice = terrainInsight.pacingAdvice
        terrainSafetyHint = terrainInsight.safetyHint

        segments.append(
            TrailSegment(
                startedAt: previous.timestamp,
                endedAt: point.timestamp,
                duration: time,
                distance: distance,
                elevationGain: elevationGain,
                slopePercent: slope,
                averageSpeed: segmentSpeed,
                heartRate: heartRate ?? 0,
                cadence: cadence,
                terrain: terrainInsight.terrain
            )
        )
        if segments.count > maxInMemorySegments {
            segments = MemorySafeCollections.mergeSegments(segments, to: maxInMemorySegments)
        }

        refreshFatigue()
        refreshSafety()
        refreshAIIfNeeded()
        persistCheckpoint(force: false)

        lastPoint = point
    }

    private func refreshFatigue() {
        var updated = fatigueService.evaluate(
            previous: fatigueState,
            elapsed: elapsed,
            speed: speed,
            slopePercent: slopePercent,
            heartRate: heartRate ?? 0,
            cadence: cadence
        )

        if let profile = profileStore.profile {
            let adjustedScore = min(100, max(0, updated.score * profile.fatigueMultiplier))
            updated.score = adjustedScore
            updated.energyRemaining = max(0, 1 - adjustedScore / 100)
        }

        fatigueState = updated
    }

    private func refreshSafety() {
        safetyState = safetyService.evaluate(
            fatigue: fatigueState,
            batteryLevel: batteryLevel,
            lastCheckIn: lastCheckIn,
            elapsed: elapsed
        )
    }

    private func refreshHeartRateAvailability() {
        guard isTracking else { return }
        guard let lastHeartRateSampleAt else { return }
        if Date().timeIntervalSince(lastHeartRateSampleAt) > heartRateStaleAfter {
            heartRate = nil
        }
    }

    private func refreshAIIfNeeded() {
        guard isTracking else { return }

        if !premiumTier.hasTerrainIntelligence {
            aiInsight = "Premium unlocks Apple Intelligence terrain and fatigue interpretation."
            return
        }

        guard segments.count % 3 == 0 else { return }
        if let lastAIRequestAt, Date().timeIntervalSince(lastAIRequestAt) < 20 {
            return
        }
        lastAIRequestAt = Date()

        let snapshot = LiveMetricsSnapshot(
            elapsed: elapsed,
            distanceMeters: totalDistance,
            elevationGain: totalElevationGain,
            speed: speed,
            slopePercent: slopePercent,
            heartRate: heartRate ?? 0,
            cadence: cadence,
            fatigue: fatigueState,
            terrain: terrain,
            trailDifficultyScore: trailDifficultyScore
        )

        Task {
            let text = await aiService.liveInsight(from: snapshot, profile: profileStore.profile)
            await MainActor.run {
                self.aiInsight = text
            }
        }
    }

    private func handleMemoryPressure() {
        if route.count > memoryWarningRoutePoints {
            route = MemorySafeCollections.downsampleRoute(route, to: memoryWarningRoutePoints)
        }
        if segments.count > memoryWarningSegments {
            segments = MemorySafeCollections.mergeSegments(segments, to: memoryWarningSegments)
        }
        aiInsight = "Memory optimized during long recording to keep tracking stable."
        persistCheckpoint(force: true)
    }

    private func startLiveServices() {
        heartRateService.start()
        cadenceService.start()
        batteryService.start()
        locationService.start()
        startClockTicker()
    }

    private func stopLiveServices() {
        clockTicker?.cancel()
        clockTicker = nil
        locationService.stop()
        heartRateService.stop()
        cadenceService.stop()
        batteryService.stop()
    }

    private func startClockTicker() {
        clockTicker?.cancel()
        clockTicker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let startDate else { return }
                elapsed = Date().timeIntervalSince(startDate)
                refreshHeartRateAvailability()
                refreshSafety()
                persistCheckpoint(force: false)
            }
    }

    private func persistCheckpoint(force: Bool) {
        guard isTracking, let startDate else { return }

        if !force,
           let lastCheckpointSavedAt,
           Date().timeIntervalSince(lastCheckpointSavedAt) < checkpointSaveInterval {
            return
        }

        let checkpoint = ActiveHikeCheckpoint(
            startedAt: startDate,
            lastCheckIn: lastCheckIn,
            route: route,
            segments: segments,
            fatigueState: fatigueState,
            safetyState: safetyState,
            cadence: cadence,
            speed: speed,
            slopePercent: slopePercent,
            batteryLevel: batteryLevel,
            terrain: terrain,
            pacingAdvice: pacingAdvice,
            terrainSafetyHint: terrainSafetyHint,
            aiInsight: aiInsight,
            currentAltitude: currentAltitude
        )
        activeHikeStore.save(checkpoint)
        lastCheckpointSavedAt = Date()
    }

    private func restoreActiveHikeIfNeeded() {
        guard !isTracking else { return }
        guard let checkpoint = activeHikeStore.load() else { return }

        isTracking = true
        startDate = checkpoint.startedAt
        lastCheckIn = checkpoint.lastCheckIn
        route = checkpoint.route
        segments = checkpoint.segments
        fatigueState = checkpoint.fatigueState
        safetyState = checkpoint.safetyState
        cadence = checkpoint.cadence
        speed = checkpoint.speed
        slopePercent = checkpoint.slopePercent
        batteryLevel = checkpoint.batteryLevel
        terrain = checkpoint.terrain
        pacingAdvice = checkpoint.pacingAdvice
        terrainSafetyHint = checkpoint.terrainSafetyHint
        aiInsight = "Recovered active hike after app restart."
        currentAltitude = checkpoint.currentAltitude
        elapsed = Date().timeIntervalSince(checkpoint.startedAt)
        lastPoint = checkpoint.route.last
        heartRate = nil
        heartRateSourceLabel = "Reconnecting heart-rate source"
        lastHeartRateSampleAt = nil
        lastCheckpointSavedAt = nil

        startLiveServices()
        persistCheckpoint(force: true)
    }
}
