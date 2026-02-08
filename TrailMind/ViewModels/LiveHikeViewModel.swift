import Foundation
import CoreLocation
import Combine

@MainActor
final class LiveHikeViewModel: ObservableObject {
    @Published private(set) var route: [LocationPoint] = []
    @Published private(set) var segments: [TrailSegment] = []
    @Published private(set) var fatigueState: FatigueState = .initial
    @Published private(set) var safetyState: SafetyState = .calm
    @Published private(set) var heartRate: Double = 0
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

    private var startDate: Date?
    private var lastCheckIn = Date()
    private var lastPoint: LocationPoint?
    private var clockTicker: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

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
        premiumService: PremiumPurchaseService
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

    var totalElevationGain: Double {
        segments.reduce(0) { $0 + max(0, $1.elevationGain) }
    }

    var trailDifficultyScore: Double {
        guard !segments.isEmpty else { return 0 }
        let avg = segments.map(\.effortIndex).reduce(0, +) / Double(segments.count)
        return min(100, avg / 2)
    }

    func startHike() {
        guard !isTracking else { return }

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

        heartRateService.start()
        cadenceService.start()
        batteryService.start()
        locationService.start()

        clockTicker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let startDate else { return }
                elapsed = Date().timeIntervalSince(startDate)
                refreshSafety()
            }
    }

    func stopHike() {
        guard isTracking, let startDate else { return }

        isTracking = false
        clockTicker?.cancel()
        clockTicker = nil

        locationService.stop()
        heartRateService.stop()
        cadenceService.stop()
        batteryService.stop()

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
    }

    func markSafetyCheckIn() {
        lastCheckIn = Date()
        refreshSafety()
    }

    private func consume(_ point: LocationPoint) {
        guard isTracking else { return }

        route.append(point)

        guard let previous = lastPoint else {
            lastPoint = point
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
                heartRate: heartRate,
                cadence: cadence,
                terrain: terrainInsight.terrain
            )
        )

        refreshFatigue()
        refreshSafety()
        refreshAIIfNeeded()

        lastPoint = point
    }

    private func refreshFatigue() {
        fatigueState = fatigueService.evaluate(
            previous: fatigueState,
            elapsed: elapsed,
            speed: speed,
            slopePercent: slopePercent,
            heartRate: heartRate,
            cadence: cadence
        )
    }

    private func refreshSafety() {
        safetyState = safetyService.evaluate(
            fatigue: fatigueState,
            batteryLevel: batteryLevel,
            lastCheckIn: lastCheckIn,
            elapsed: elapsed
        )
    }

    private func refreshAIIfNeeded() {
        guard isTracking else { return }

        if !premiumTier.hasTerrainIntelligence {
            aiInsight = "Premium unlocks Apple Intelligence terrain and fatigue interpretation."
            return
        }

        guard segments.count % 3 == 0 else { return }

        let snapshot = LiveMetricsSnapshot(
            elapsed: elapsed,
            speed: speed,
            slopePercent: slopePercent,
            heartRate: heartRate,
            cadence: cadence,
            fatigue: fatigueState,
            terrain: terrain
        )

        Task {
            let text = await aiService.liveInsight(from: snapshot)
            await MainActor.run {
                self.aiInsight = text
            }
        }
    }
}
