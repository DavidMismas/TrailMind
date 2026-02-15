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
    @Published private(set) var isPaused = false
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
    private let liveActivityService: LiveActivityService
    private let cacheService: OfflineTrailCacheService
    private let activeHikeStore: ActiveHikeStatePersistenceService
    private let profileStore: UserProfileStore
    private let watchConnectivityService: WatchConnectivityService

    private var startDate: Date?
    private var lastCheckIn = Date()
    private var lastPoint: LocationPoint?
    private var clockTicker: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var lastAIRequestAt: Date?
    private var lastHeartRateSampleAt: Date?
    private var lastCheckpointSavedAt: Date?
    private var pausedAccumulatedSeconds: TimeInterval = 0
    private var pausedStartedAt: Date?
    private var lastFilteredAltitude: Double?

    private let maxInMemoryRoutePoints = 4000
    private let maxInMemorySegments = 6000
    private let memoryWarningRoutePoints = 1500
    private let memoryWarningSegments = 2200
    private let heartRateStaleAfter: TimeInterval = 25
    private let checkpointSaveInterval: TimeInterval = 4
    private let liveActivityUpdateInterval: TimeInterval = 3
    private let liveActivityDistanceDelta: Double = 2
    private let maxWidgetAltitudeSamples = 90
    private let maxReliableVerticalAccuracy: Double = 16
    private let minAltitudeStepMeters: Double = 1.4
    private let maxVerticalSpeedMetersPerSecond: Double = 4.5

    private var lastLiveActivityUpdateAt: Date?
    private var lastLiveActivityDistanceMeters: Double = 0

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
        liveActivityService: LiveActivityService,
        cacheService: OfflineTrailCacheService,
        activeHikeStore: ActiveHikeStatePersistenceService,
        premiumService: PremiumPurchaseService,

        profileStore: UserProfileStore,
        watchConnectivityService: WatchConnectivityService
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
        self.liveActivityService = liveActivityService
        self.cacheService = cacheService
        self.activeHikeStore = activeHikeStore
        self.profileStore = profileStore
        self.watchConnectivityService = watchConnectivityService

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

        watchConnectivityService.commandPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                self?.handleWatchCommand(command)
            }
            .store(in: &cancellables)
            
        watchConnectivityService.start()

        restoreActiveHikeIfNeeded()
    }

    var energyToGoalText: String {
        guard isTracking else { return "Start tracking to estimate energy." }
        guard premiumTier.hasEnergyPrediction else { return "Premium unlocks energy-to-goal prediction." }

        if fatigueState.energyRemaining > 0.55 {
            if fatigueState.caloriesConsumed <= 0, elapsed > 45 * 60 {
                return "Energy looks stable. Consider a small carb intake before the next long climb."
            }
            return "Likely enough energy for the current route."
        }
        if fatigueState.energyRemaining > 0.3 {
            return "Energy is moderate. Plan a short break soon."
        }
        return "Energy is low. Consider turning back early."
    }

    var estimatedCaloriesBurnedText: String {
        "\(Int(fatigueState.estimatedCaloriesBurned.rounded())) kcal burned"
    }

    var consumedCaloriesText: String {
        "\(Int(fatigueState.caloriesConsumed.rounded())) kcal consumed"
    }

    var netEnergyText: String {
        let net = fatigueState.caloriesConsumed - fatigueState.estimatedCaloriesBurned
        if net >= 0 {
            return "+\(Int(net.rounded())) kcal net"
        }
        return "\(Int(net.rounded())) kcal net"
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
        isPaused = false
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
        lastLiveActivityUpdateAt = nil
        lastLiveActivityDistanceMeters = 0
        pausedAccumulatedSeconds = 0
        pausedStartedAt = nil
        lastFilteredAltitude = nil
        currentAltitude = 0

        if let startDate {
            liveActivityService.start(
                startedAt: startDate,
                elapsed: elapsed,
                distanceMeters: totalDistance,
                currentAltitudeMeters: currentAltitude,
                elevationGainMeters: totalElevationGain,
                altitudeSamples: buildLiveAltitudeSamples()
            )
        }
        startLiveServices()
        persistCheckpoint(force: true)
        
        watchConnectivityService.send(.startHike)
    }

    func stopHike() {
        guard isTracking, let startDate else { return }

        let stopTimestamp = Date()
        let finalElapsed = elapsedAt(stopTimestamp)
        elapsed = finalElapsed
        isTracking = false
        isPaused = false
        pausedStartedAt = nil
        stopLiveServices()
        let finalDistance = totalDistance
        liveActivityService.stop(
            startedAt: startDate,
            elapsed: finalElapsed,
            distanceMeters: finalDistance,
            currentAltitudeMeters: currentAltitude,
            elevationGainMeters: totalElevationGain,
            altitudeSamples: buildLiveAltitudeSamples()
        )
        heartRate = nil
        heartRateSourceLabel = "No heart-rate source"
        lastHeartRateSampleAt = nil
        lastCheckpointSavedAt = nil
        lastLiveActivityUpdateAt = nil
        lastLiveActivityDistanceMeters = 0
        pausedAccumulatedSeconds = 0
        lastFilteredAltitude = nil

        let session = HikeSession(
            startedAt: startDate,
            endedAt: stopTimestamp,
            route: route,
            segments: segments,
            finalFatigue: fatigueState,
            finalSafety: safetyState
        )
        sessionStore.add(session)
        cacheService.cache(route: route, sessionID: session.id)
        activeHikeStore.clear()
        
        watchConnectivityService.send(.stopHike)
    }

    func markSafetyCheckIn() {
        lastCheckIn = Date()
        refreshSafety()
        persistCheckpoint(force: true)
    }

    func pauseHike() {
        guard isTracking, !isPaused else { return }
        elapsed = elapsedAt(Date())
        isPaused = true
        pausedStartedAt = Date()
        speed = 0
        slopePercent = 0
        pacingAdvice = "Tracking paused."
        refreshSafety()
        updateLiveActivityIfNeeded(force: true)
        persistCheckpoint(force: true)
    }

    func resumeHike() {
        guard isTracking, isPaused else { return }
        if let pausedStartedAt {
            pausedAccumulatedSeconds += max(0, Date().timeIntervalSince(pausedStartedAt))
        }
        isPaused = false
        self.pausedStartedAt = nil
        elapsed = elapsedAt(Date())
        lastPoint = nil
        pacingAdvice = "Resumed. Move to refresh pace guidance."
        refreshSafety()
        updateLiveActivityIfNeeded(force: true)
        persistCheckpoint(force: true)
    }

    func logCalories(_ calories: Double) {
        guard isTracking else { return }
        let intake = max(0, calories)
        guard intake > 0 else { return }

        elapsed = elapsedAt(Date())
        fatigueState.caloriesConsumed += intake
        refreshFatigue()
        refreshSafety()
        persistCheckpoint(force: true)
    }

    private func consume(_ point: LocationPoint) {
        guard isTracking else { return }
        elapsed = elapsedAt(point.timestamp)

        let previousFilteredAltitude = lastFilteredAltitude
        let filteredAltitude = filteredAltitude(for: point, previousFilteredAltitude: previousFilteredAltitude)
        currentAltitude = filteredAltitude

        if isPaused {
            lastFilteredAltitude = filteredAltitude
            persistCheckpoint(force: false)
            return
        }

        route.append(point)
        if route.count > maxInMemoryRoutePoints {
            route = MemorySafeCollections.downsampleRoute(route, to: maxInMemoryRoutePoints)
        }

        guard let previous = lastPoint else {
            lastPoint = point
            lastFilteredAltitude = filteredAltitude
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
        let baselineAltitude = previousFilteredAltitude ?? previous.altitude
        let rawVerticalDelta = filteredAltitude - baselineAltitude
        let cappedVerticalDelta = cappedAltitudeDelta(rawVerticalDelta, duration: time)
        let verticalDelta = filteredVerticalDelta(cappedVerticalDelta)
        let slope = distance > 0 ? (verticalDelta / distance) * 100 : 0

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
                elevationGain: verticalDelta,
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
        updateLiveActivityIfNeeded(force: false)
        persistCheckpoint(force: false)

        lastPoint = point
        lastFilteredAltitude = filteredAltitude
    }

    private func refreshFatigue() {
        let updated = fatigueService.evaluate(
            previous: fatigueState,
            elapsed: elapsed,
            speed: speed,
            slopePercent: slopePercent,
            heartRate: heartRate ?? 0,
            cadence: cadence,
            profile: profileStore.profile
        )

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
        guard !isPaused else { return }

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
                guard let self, self.startDate != nil else { return }
                elapsed = elapsedAt(Date())
                refreshHeartRateAvailability()
                refreshSafety()
                updateLiveActivityIfNeeded(force: false)
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
            currentAltitude: currentAltitude,
            isPaused: isPaused,
            pausedAccumulatedSeconds: pausedAccumulatedSeconds,
            pausedStartedAt: pausedStartedAt,
            lastFilteredAltitude: lastFilteredAltitude
        )
        activeHikeStore.save(checkpoint)
        lastCheckpointSavedAt = Date()
    }

    private func restoreActiveHikeIfNeeded() {
        guard !isTracking else { return }
        guard let checkpoint = activeHikeStore.load() else { return }

        isTracking = true
        isPaused = checkpoint.isPaused
        startDate = checkpoint.startedAt
        lastCheckIn = checkpoint.lastCheckIn
        route = checkpoint.route
        segments = checkpoint.segments
        fatigueState = checkpoint.fatigueState
        safetyState = checkpoint.safetyState
        cadence = checkpoint.cadence
        speed = checkpoint.speed
        slopePercent = checkpoint.slopePercent
        if checkpoint.isPaused {
            speed = 0
            slopePercent = 0
        }
        batteryLevel = checkpoint.batteryLevel
        terrain = checkpoint.terrain
        pacingAdvice = checkpoint.pacingAdvice
        terrainSafetyHint = checkpoint.terrainSafetyHint
        aiInsight = "Recovered active hike after app restart."
        currentAltitude = checkpoint.currentAltitude
        pausedAccumulatedSeconds = checkpoint.pausedAccumulatedSeconds
        pausedStartedAt = checkpoint.pausedStartedAt ?? (checkpoint.isPaused ? Date() : nil)
        elapsed = elapsedAt(Date())
        lastPoint = checkpoint.route.last
        lastFilteredAltitude = checkpoint.lastFilteredAltitude ?? checkpoint.route.last?.altitude ?? checkpoint.currentAltitude
        heartRate = nil
        heartRateSourceLabel = "Reconnecting heart-rate source"
        lastHeartRateSampleAt = nil
        lastCheckpointSavedAt = nil
        lastLiveActivityUpdateAt = nil
        lastLiveActivityDistanceMeters = totalDistance

        liveActivityService.start(
            startedAt: checkpoint.startedAt,
            elapsed: elapsed,
            distanceMeters: totalDistance,
            currentAltitudeMeters: currentAltitude,
            elevationGainMeters: totalElevationGain,
            altitudeSamples: buildLiveAltitudeSamples()
        )
        startLiveServices()
        updateLiveActivityIfNeeded(force: true)
        persistCheckpoint(force: true)
    }

    private func updateLiveActivityIfNeeded(force: Bool) {
        guard isTracking, let startDate else { return }

        let now = Date()
        let distance = totalDistance
        if !force {
            let recentlyUpdated = (lastLiveActivityUpdateAt.map { now.timeIntervalSince($0) < liveActivityUpdateInterval } ?? false)
            let distanceDelta = abs(distance - lastLiveActivityDistanceMeters)
            if recentlyUpdated && distanceDelta < liveActivityDistanceDelta {
                return
            }
        }

        let liveElapsed = elapsedAt(now)
        liveActivityService.update(
            startedAt: startDate,
            elapsed: liveElapsed,
            distanceMeters: distance,
            currentAltitudeMeters: currentAltitude,
            elevationGainMeters: totalElevationGain,
            altitudeSamples: buildLiveAltitudeSamples()
        )
        lastLiveActivityUpdateAt = now
        lastLiveActivityDistanceMeters = distance
    }

    private func buildLiveAltitudeSamples() -> [LiveAltitudeSample] {
        guard !route.isEmpty else {
            return [
                LiveAltitudeSample(distanceMeters: 0, altitudeMeters: currentAltitude)
            ]
        }

        var samples: [LiveAltitudeSample] = []
        samples.reserveCapacity(route.count)

        var cumulativeDistance: Double = 0
        samples.append(
            LiveAltitudeSample(
                distanceMeters: cumulativeDistance,
                altitudeMeters: route[0].altitude
            )
        )

        if route.count > 1 {
            for index in 1..<route.count {
                let previous = route[index - 1]
                let current = route[index]
                let stepDistance = CLLocation(
                    latitude: previous.coordinate.latitude,
                    longitude: previous.coordinate.longitude
                ).distance(
                    from: CLLocation(
                        latitude: current.coordinate.latitude,
                        longitude: current.coordinate.longitude
                    )
                )
                cumulativeDistance += max(0, stepDistance)
                samples.append(
                    LiveAltitudeSample(
                        distanceMeters: cumulativeDistance,
                        altitudeMeters: current.altitude
                    )
                )
            }
        }

        return downsampleAltitudeSamples(samples, to: maxWidgetAltitudeSamples)
    }

    private func downsampleAltitudeSamples(
        _ samples: [LiveAltitudeSample],
        to maxCount: Int
    ) -> [LiveAltitudeSample] {
        guard maxCount > 1, samples.count > maxCount else { return samples }

        let lastIndex = samples.count - 1
        var result: [LiveAltitudeSample] = []
        result.reserveCapacity(maxCount)

        for index in 0..<maxCount {
            let ratio = Double(index) / Double(maxCount - 1)
            let sourceIndex = Int((Double(lastIndex) * ratio).rounded())
            result.append(samples[min(lastIndex, sourceIndex)])
        }

        return result
    }

    private func elapsedAt(_ date: Date) -> TimeInterval {
        guard let startDate else { return 0 }
        let livePausedSeconds: TimeInterval
        if isPaused, let pausedStartedAt {
            livePausedSeconds = max(0, date.timeIntervalSince(pausedStartedAt))
        } else {
            livePausedSeconds = 0
        }
        return max(0, date.timeIntervalSince(startDate) - pausedAccumulatedSeconds - livePausedSeconds)
    }

    private func filteredAltitude(
        for point: LocationPoint,
        previousFilteredAltitude: Double?
    ) -> Double {
        let hasReliableVerticalAccuracy = point.verticalAccuracy >= 0 && point.verticalAccuracy <= maxReliableVerticalAccuracy
        guard hasReliableVerticalAccuracy else {
            return previousFilteredAltitude ?? point.altitude
        }

        guard let previousFilteredAltitude else {
            return point.altitude
        }

        let alpha = altitudeSmoothingAlpha(for: point.verticalAccuracy)
        return previousFilteredAltitude + (point.altitude - previousFilteredAltitude) * alpha
    }

    private func altitudeSmoothingAlpha(for verticalAccuracy: Double) -> Double {
        if verticalAccuracy <= 4 { return 0.45 }
        if verticalAccuracy <= 8 { return 0.32 }
        return 0.2
    }

    private func cappedAltitudeDelta(_ delta: Double, duration: TimeInterval) -> Double {
        let maxDelta = maxVerticalSpeedMetersPerSecond * max(1, duration)
        return min(max(delta, -maxDelta), maxDelta)
    }

    private func filteredVerticalDelta(_ delta: Double) -> Double {
        if abs(delta) < minAltitudeStepMeters {
            return 0
        }
        return delta
    }

    private func handleWatchCommand(_ command: WatchCommand) {
        switch command {
        case .startHike:
            if !isTracking {
                startHike()
            }
        case .stopHike:
            if isTracking {
                stopHike()
            }
        }
    }
}
