import Foundation

struct ActiveHikeCheckpoint: Codable {
    let startedAt: Date
    let lastCheckIn: Date
    let route: [LocationPoint]
    let segments: [TrailSegment]
    let fatigueState: FatigueState
    let safetyState: SafetyState
    let cadence: Double
    let speed: Double
    let slopePercent: Double
    let batteryLevel: Double
    let terrain: TerrainType
    let pacingAdvice: String
    let terrainSafetyHint: String
    let aiInsight: String
    let currentAltitude: Double
    let isPaused: Bool
    let pausedAccumulatedSeconds: TimeInterval
    let pausedStartedAt: Date?
    let lastFilteredAltitude: Double?

    enum CodingKeys: String, CodingKey {
        case startedAt
        case lastCheckIn
        case route
        case segments
        case fatigueState
        case safetyState
        case cadence
        case speed
        case slopePercent
        case batteryLevel
        case terrain
        case pacingAdvice
        case terrainSafetyHint
        case aiInsight
        case currentAltitude
        case isPaused
        case pausedAccumulatedSeconds
        case pausedStartedAt
        case lastFilteredAltitude
    }

    init(
        startedAt: Date,
        lastCheckIn: Date,
        route: [LocationPoint],
        segments: [TrailSegment],
        fatigueState: FatigueState,
        safetyState: SafetyState,
        cadence: Double,
        speed: Double,
        slopePercent: Double,
        batteryLevel: Double,
        terrain: TerrainType,
        pacingAdvice: String,
        terrainSafetyHint: String,
        aiInsight: String,
        currentAltitude: Double,
        isPaused: Bool = false,
        pausedAccumulatedSeconds: TimeInterval = 0,
        pausedStartedAt: Date? = nil,
        lastFilteredAltitude: Double? = nil
    ) {
        self.startedAt = startedAt
        self.lastCheckIn = lastCheckIn
        self.route = route
        self.segments = segments
        self.fatigueState = fatigueState
        self.safetyState = safetyState
        self.cadence = cadence
        self.speed = speed
        self.slopePercent = slopePercent
        self.batteryLevel = batteryLevel
        self.terrain = terrain
        self.pacingAdvice = pacingAdvice
        self.terrainSafetyHint = terrainSafetyHint
        self.aiInsight = aiInsight
        self.currentAltitude = currentAltitude
        self.isPaused = isPaused
        self.pausedAccumulatedSeconds = pausedAccumulatedSeconds
        self.pausedStartedAt = pausedStartedAt
        self.lastFilteredAltitude = lastFilteredAltitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        lastCheckIn = try container.decode(Date.self, forKey: .lastCheckIn)
        route = try container.decode([LocationPoint].self, forKey: .route)
        segments = try container.decode([TrailSegment].self, forKey: .segments)
        fatigueState = try container.decode(FatigueState.self, forKey: .fatigueState)
        safetyState = try container.decode(SafetyState.self, forKey: .safetyState)
        cadence = try container.decode(Double.self, forKey: .cadence)
        speed = try container.decode(Double.self, forKey: .speed)
        slopePercent = try container.decode(Double.self, forKey: .slopePercent)
        batteryLevel = try container.decode(Double.self, forKey: .batteryLevel)
        terrain = try container.decode(TerrainType.self, forKey: .terrain)
        pacingAdvice = try container.decode(String.self, forKey: .pacingAdvice)
        terrainSafetyHint = try container.decode(String.self, forKey: .terrainSafetyHint)
        aiInsight = try container.decode(String.self, forKey: .aiInsight)
        currentAltitude = try container.decode(Double.self, forKey: .currentAltitude)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        pausedAccumulatedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .pausedAccumulatedSeconds) ?? 0
        pausedStartedAt = try container.decodeIfPresent(Date.self, forKey: .pausedStartedAt)
        lastFilteredAltitude = try container.decodeIfPresent(Double.self, forKey: .lastFilteredAltitude)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(lastCheckIn, forKey: .lastCheckIn)
        try container.encode(route, forKey: .route)
        try container.encode(segments, forKey: .segments)
        try container.encode(fatigueState, forKey: .fatigueState)
        try container.encode(safetyState, forKey: .safetyState)
        try container.encode(cadence, forKey: .cadence)
        try container.encode(speed, forKey: .speed)
        try container.encode(slopePercent, forKey: .slopePercent)
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encode(terrain, forKey: .terrain)
        try container.encode(pacingAdvice, forKey: .pacingAdvice)
        try container.encode(terrainSafetyHint, forKey: .terrainSafetyHint)
        try container.encode(aiInsight, forKey: .aiInsight)
        try container.encode(currentAltitude, forKey: .currentAltitude)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encode(pausedAccumulatedSeconds, forKey: .pausedAccumulatedSeconds)
        try container.encodeIfPresent(pausedStartedAt, forKey: .pausedStartedAt)
        try container.encodeIfPresent(lastFilteredAltitude, forKey: .lastFilteredAltitude)
    }
}
