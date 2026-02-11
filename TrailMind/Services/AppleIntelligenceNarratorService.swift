import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

final class AppleIntelligenceNarratorService: AppleIntelligenceService {
    private let englishPOSIXLocale = Locale(identifier: "en_US_POSIX")

    func liveInsight(from snapshot: LiveMetricsSnapshot, profile: UserProfile?) async -> String {
        let fallback = fallbackLiveInsight(from: snapshot)

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            let localeSupport = modelLocaleSupport(for: model)
            if localeSupport.hasRegionOverride {
                print("[AI] liveInsight skipped due to locale region override: \(localeSupport.current.identifier)")
                return fallback
            }
            guard model.isAvailable, (localeSupport.supportsCurrent || localeSupport.supportsNormalized) else {
                return fallback
            }

            let session = LanguageModelSession(model: model) {
                """
                You are a concise hiking coach.
                Use only provided metrics.
                Reply in English (United States).
                Return exactly one practical sentence.
                Max 24 words.
                No markdown, no bullets.
                """
            }

            do {
                let response = try await session.respond(
                    to: livePrompt(snapshot: snapshot, profile: profile),
                    options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 70)
                )
                let cleaned = cleanSingleLine(response.content)
                return cleaned.isEmpty ? fallback : cleaned
            } catch {
                print("[AI] liveInsight error: \(error)")
                return fallback
            }
        }
#endif
        return fallback
    }

    func postHikeInsights(
        for session: HikeSession,
        historicalSessions: [HikeSession],
        profile: UserProfile?
    ) async -> [PerformanceInsight]? {
        // Require at least some meaningful hike data before calling the model.
        // An all-zero session (e.g. a demo/empty hike) triggers content guardrails.
        guard session.totalDistance > 0 || session.totalElevationGain > 0 || session.duration > 0 else {
            print("[AI] postHike skipped — empty hike session")
            return nil
        }

        let stats = buildPostHikeStats(
            session: session,
            historical: historicalSessions,
            profile: profile
        )

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            let localeSupport = modelLocaleSupport(for: model)
            print(
                "[AI] postHike isAvailable=\(model.isAvailable) " +
                "supportsCurrentLocale=\(localeSupport.supportsCurrent) " +
                "supportsNormalizedLocale=\(localeSupport.supportsNormalized) " +
                "hasRegionOverride=\(localeSupport.hasRegionOverride) " +
                "locale=\(localeSupport.current.identifier) " +
                "normalizedLocale=\(localeSupport.normalized.identifier) " +
                "availability=\(model.availability) " +
                "supportedLanguagesCount=\(model.supportedLanguages.count)"
            )
            if localeSupport.hasRegionOverride {
                print("[AI] postHike skipped due to locale region override: \(localeSupport.current.identifier)")
            } else if model.isAvailable, (localeSupport.supportsCurrent || localeSupport.supportsNormalized) {
                if let aiInsights = await generatePostHikeInsightsWithModel(model: model, stats: stats) {
                    return aiInsights
                }
            }
        }
#endif
        let fallback = deterministicPostHikeInsights(from: stats)
        return fallback.isEmpty ? nil : fallback
    }

    private func fallbackLiveInsight(from snapshot: LiveMetricsSnapshot) -> String {
        let fatigueText: String
        if snapshot.fatigue.score > 75 {
            fatigueText = "Current pace on this section is likely to cause early fatigue."
        } else if snapshot.fatigue.score > 45 {
            fatigueText = "Moderate load detected, keep cadence smooth to preserve energy."
        } else {
            fatigueText = "Load is under control for now."
        }

        switch snapshot.terrain {
        case .climb:
            return "\(fatigueText) On this climb, reduce pace by about 10% for better endurance."
        case .downhill:
            return "\(fatigueText) Keep downhill steps short to reduce joint stress."
        case .technical:
            return "\(fatigueText) Technical terrain detected, prioritize stability over speed."
        case .flat:
            return "\(fatigueText) Flat section is a good place to recover rhythm."
        }
    }

    private func livePrompt(snapshot: LiveMetricsSnapshot, profile: UserProfile?) -> String {
        let profileText: String
        if let profile {
            profileText = "Profile: age \(profile.age), weight \(Int(profile.weightKg))kg, height \(Int(profile.heightCm))cm, condition \(profile.condition.rawValue)."
        } else {
            profileText = "Profile: unavailable."
        }

        let paceText = formattedPace(from: snapshot.speed)
        let heartRateText = snapshot.heartRate > 0 ? "\(Int(snapshot.heartRate.rounded())) bpm" : "unavailable"

        return """
        \(profileText)
        Live metrics:
        - elapsed: \(Int(snapshot.elapsed / 60)) min
        - distance: \(decimal(snapshot.distanceMeters / 1000, digits: 2)) km
        - elevation gain: \(Int(snapshot.elevationGain.rounded())) m
        - pace: \(paceText)
        - slope: \(decimal(snapshot.slopePercent, digits: 1))%
        - heart rate: \(heartRateText)
        - cadence: \(decimal(snapshot.cadence, digits: 2))
        - fatigue score: \(Int(snapshot.fatigue.score.rounded()))
        - energy remaining: \(Int((snapshot.fatigue.energyRemaining * 100).rounded()))%
        - trail difficulty: \(Int(snapshot.trailDifficultyScore.rounded()))
        - terrain: \(snapshot.terrain.rawValue)
        Give one immediate action for the next 2-5 minutes.
        """
    }

    private enum PostHikePromptStyle {
        case detailed
        case compact
    }

    private struct PostHikeStats {
        let profile: UserProfile?
        let historicalCount: Int

        let durationMinutes: Double
        let distanceKm: Double
        let elevationGainM: Double
        let averageSpeed: Double
        let maxSpeed: Double
        let minSpeed: Double
        let averagePaceText: String

        let segmentCount: Int
        let routePointCount: Int
        let averageGPSAccuracy: Double?
        let altitudeRange: Double?
        let netAltitude: Double?

        let averageSlopePercent: Double
        let steepestClimbPercent: Double
        let steepestDescentPercent: Double
        let averageCadence: Double
        let maxCadence: Double
        let averageHeartRate: Double?
        let maxHeartRate: Double?

        let fatigueScore: Double
        let energyRemainingPercent: Double
        let energyUsedPercent: Double
        let trailDifficultyScore: Double
        let safety: SafetyState

        let climbPercent: Double
        let downhillPercent: Double
        let technicalPercent: Double
        let flatPercent: Double
        let dominantTerrain: TerrainType
        let climbEffort: Double?
        let downhillEffort: Double?
        let technicalEffort: Double?
        let flatEffort: Double?

        let firstHalfSpeed: Double
        let secondHalfSpeed: Double
        let firstHalfEffort: Double
        let secondHalfEffort: Double

        let historicalAvgDistanceKm: Double?
        let historicalAvgGainM: Double?
        let historicalAvgDurationMinutes: Double?
        let historicalAvgFatigue: Double?
        let historicalAvgDifficulty: Double?
        let personalBestDistanceKm: Double?
        let personalBestGainM: Double?
        let distanceDeltaPercent: Double?
        let fatigueDelta: Double?
    }

    private func buildPostHikeStats(
        session: HikeSession,
        historical: [HikeSession],
        profile: UserProfile?
    ) -> PostHikeStats {
        let orderedSegments = session.segments.sorted { $0.startedAt < $1.startedAt }
        let durationMinutes = max(0, session.duration / 60)
        let distanceKm = session.totalDistance / 1000
        let elevationGainM = session.totalElevationGain
        let averageSpeed = session.duration > 0 ? session.totalDistance / session.duration : 0
        let maxSpeed = orderedSegments.map(\.averageSpeed).max() ?? 0
        let minSpeed = orderedSegments.map(\.averageSpeed).min() ?? 0

        let heartRates = orderedSegments.map(\.heartRate).filter { $0 > 0 }
        let averageHeartRate = average(of: heartRates)
        let maxHeartRate = heartRates.max()

        let routeAltitudes = session.route.map(\.altitude)
        let altitudeRange: Double?
        if let minAltitude = routeAltitudes.min(), let maxAltitude = routeAltitudes.max() {
            altitudeRange = maxAltitude - minAltitude
        } else {
            altitudeRange = nil
        }

        let netAltitude: Double?
        if let firstAltitude = session.route.first?.altitude, let lastAltitude = session.route.last?.altitude {
            netAltitude = lastAltitude - firstAltitude
        } else {
            netAltitude = nil
        }

        let gpsAccuracySamples = session.route.map(\.horizontalAccuracy).filter { $0 > 0 }
        let averageGPSAccuracy = average(of: gpsAccuracySamples)

        let averageSlopePercent = average(of: orderedSegments.map(\.slopePercent)) ?? 0
        let steepestClimbPercent = orderedSegments.map(\.slopePercent).filter { $0 > 0 }.max() ?? 0
        let steepestDescentPercent = abs(orderedSegments.map(\.slopePercent).filter { $0 < 0 }.min() ?? 0)
        let averageCadence = average(of: orderedSegments.map(\.cadence)) ?? 0
        let maxCadence = orderedSegments.map(\.cadence).max() ?? 0

        let climbDuration = orderedSegments.filter { $0.terrain == .climb }.map(\.duration).reduce(0, +)
        let downhillDuration = orderedSegments.filter { $0.terrain == .downhill }.map(\.duration).reduce(0, +)
        let technicalDuration = orderedSegments.filter { $0.terrain == .technical }.map(\.duration).reduce(0, +)
        let flatDuration = orderedSegments.filter { $0.terrain == .flat }.map(\.duration).reduce(0, +)
        let terrainTotalDuration = max(1.0, climbDuration + downhillDuration + technicalDuration + flatDuration)

        let dominantTerrain = [
            (TerrainType.climb, climbDuration),
            (TerrainType.downhill, downhillDuration),
            (TerrainType.technical, technicalDuration),
            (TerrainType.flat, flatDuration)
        ].max(by: { $0.1 < $1.1 })?.0 ?? .flat

        let splitIndex = max(1, orderedSegments.count / 2)
        let firstHalfSegments = Array(orderedSegments.prefix(splitIndex))
        let secondHalfRaw = Array(orderedSegments.dropFirst(splitIndex))
        let secondHalfSegments = secondHalfRaw.isEmpty ? firstHalfSegments : secondHalfRaw

        let firstHalfSpeed = average(of: firstHalfSegments.map(\.averageSpeed)) ?? 0
        let secondHalfSpeed = average(of: secondHalfSegments.map(\.averageSpeed)) ?? 0
        let firstHalfEffort = average(of: firstHalfSegments.map(\.effortIndex)) ?? 0
        let secondHalfEffort = average(of: secondHalfSegments.map(\.effortIndex)) ?? 0

        let historicalDistancesKm = historical.map { $0.totalDistance / 1000 }
        let historicalGainsM = historical.map(\.totalElevationGain)
        let historicalDurationsMinutes = historical.map { $0.duration / 60 }
        let historicalFatigue = historical.map(\.finalFatigue.score)
        let historicalDifficulty = historical.map(\.trailDifficultyScore)

        let historicalAvgDistanceKm = average(of: historicalDistancesKm)
        let historicalAvgGainM = average(of: historicalGainsM)
        let historicalAvgDurationMinutes = average(of: historicalDurationsMinutes)
        let historicalAvgFatigue = average(of: historicalFatigue)
        let historicalAvgDifficulty = average(of: historicalDifficulty)
        let personalBestDistanceKm = historicalDistancesKm.max()
        let personalBestGainM = historicalGainsM.max()

        let distanceDeltaPercent: Double?
        if let historicalAvgDistanceKm, historicalAvgDistanceKm > 0 {
            distanceDeltaPercent = ((distanceKm - historicalAvgDistanceKm) / historicalAvgDistanceKm) * 100
        } else {
            distanceDeltaPercent = nil
        }

        let fatigueDelta: Double?
        if let historicalAvgFatigue {
            fatigueDelta = session.finalFatigue.score - historicalAvgFatigue
        } else {
            fatigueDelta = nil
        }

        return PostHikeStats(
            profile: profile,
            historicalCount: historical.count,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
            elevationGainM: elevationGainM,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            minSpeed: minSpeed,
            averagePaceText: formattedPace(from: averageSpeed),
            segmentCount: orderedSegments.count,
            routePointCount: session.route.count,
            averageGPSAccuracy: averageGPSAccuracy,
            altitudeRange: altitudeRange,
            netAltitude: netAltitude,
            averageSlopePercent: averageSlopePercent,
            steepestClimbPercent: steepestClimbPercent,
            steepestDescentPercent: steepestDescentPercent,
            averageCadence: averageCadence,
            maxCadence: maxCadence,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            fatigueScore: session.finalFatigue.score,
            energyRemainingPercent: session.finalFatigue.energyRemaining * 100,
            energyUsedPercent: (1 - session.finalFatigue.energyRemaining) * 100,
            trailDifficultyScore: session.trailDifficultyScore,
            safety: session.finalSafety,
            climbPercent: (climbDuration / terrainTotalDuration) * 100,
            downhillPercent: (downhillDuration / terrainTotalDuration) * 100,
            technicalPercent: (technicalDuration / terrainTotalDuration) * 100,
            flatPercent: (flatDuration / terrainTotalDuration) * 100,
            dominantTerrain: dominantTerrain,
            climbEffort: average(of: orderedSegments.filter { $0.terrain == .climb }.map(\.effortIndex)),
            downhillEffort: average(of: orderedSegments.filter { $0.terrain == .downhill }.map(\.effortIndex)),
            technicalEffort: average(of: orderedSegments.filter { $0.terrain == .technical }.map(\.effortIndex)),
            flatEffort: average(of: orderedSegments.filter { $0.terrain == .flat }.map(\.effortIndex)),
            firstHalfSpeed: firstHalfSpeed,
            secondHalfSpeed: secondHalfSpeed,
            firstHalfEffort: firstHalfEffort,
            secondHalfEffort: secondHalfEffort,
            historicalAvgDistanceKm: historicalAvgDistanceKm,
            historicalAvgGainM: historicalAvgGainM,
            historicalAvgDurationMinutes: historicalAvgDurationMinutes,
            historicalAvgFatigue: historicalAvgFatigue,
            historicalAvgDifficulty: historicalAvgDifficulty,
            personalBestDistanceKm: personalBestDistanceKm,
            personalBestGainM: personalBestGainM,
            distanceDeltaPercent: distanceDeltaPercent,
            fatigueDelta: fatigueDelta
        )
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generatePostHikeInsightsWithModel(
        model: SystemLanguageModel,
        stats: PostHikeStats
    ) async -> [PerformanceInsight]? {
        let prompts = [
            postHikePrompt(from: stats, style: .detailed),
            postHikePrompt(from: stats, style: .compact)
        ]

        for (index, promptText) in prompts.enumerated() {
            let lmSession = LanguageModelSession(model: model) {
                """
                You are an elite hiking performance analyst.
                Output language must be English (United States).
                Use only data provided by the prompt.
                Return exactly 3 lines in format: Title|Detail
                Title max 4 words.
                Detail max 130 characters.
                No markdown, no bullet points, no numbering.
                """
            }

            print("[AI] postHike prompt[\(index)]:\n\(promptText)")

            do {
                let response = try await lmSession.respond(
                    to: promptText,
                    options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 300)
                )
                let rawOutput = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                print("[AI] postHike raw output[\(index)]: \(rawOutput)")

                let parsed = parseInsights(from: rawOutput)
                if !parsed.isEmpty {
                    return parsed
                }

                let parsedFallback = fallbackInsights(from: rawOutput)
                print("[AI] postHike parsed=\(parsed.count) fallback=\(parsedFallback.count)")
                if !parsedFallback.isEmpty {
                    return parsedFallback
                }
            } catch let generationError as LanguageModelSession.GenerationError {
                switch generationError {
                case .unsupportedLanguageOrLocale(let context):
                    print("[AI] postHike unsupportedLanguageOrLocale on prompt[\(index)]: \(context.debugDescription)")
                default:
                    print("[AI] postHike generation error on prompt[\(index)]: \(generationError)")
                }
            } catch {
                print("[AI] postHike error on prompt[\(index)]: \(error)")
            }
        }

        return nil
    }
#endif

    private func postHikePrompt(from stats: PostHikeStats, style: PostHikePromptStyle) -> String {
        let profileText: String
        if let profile = stats.profile {
            profileText = "Age \(profile.age), weight \(Int(profile.weightKg.rounded())) kg, height \(Int(profile.heightCm.rounded())) cm, condition \(profile.condition.rawValue), fatigue multiplier \(decimal(profile.fatigueMultiplier, digits: 2))."
        } else {
            profileText = "Profile unavailable."
        }

        let routeText: String
        if let altitudeRange = stats.altitudeRange, let netAltitude = stats.netAltitude {
            let accuracyText = stats.averageGPSAccuracy.map { "\(decimal($0, digits: 1)) m average accuracy" } ?? "GPS accuracy unavailable"
            routeText = "Route points \(stats.routePointCount), altitude range \(Int(altitudeRange.rounded())) m, net altitude \(Int(netAltitude.rounded())) m, \(accuracyText)."
        } else {
            routeText = "Route points \(stats.routePointCount), altitude trend unavailable."
        }

        let heartRateText: String
        if let averageHeartRate = stats.averageHeartRate, let maxHeartRate = stats.maxHeartRate {
            heartRateText = "Heart rate average \(Int(averageHeartRate.rounded())) bpm, max \(Int(maxHeartRate.rounded())) bpm."
        } else {
            heartRateText = "Heart rate unavailable."
        }

        let historyText: String
        if stats.historicalCount > 0 {
            historyText = """
            History count \(stats.historicalCount).
            Baseline distance \(decimal(stats.historicalAvgDistanceKm ?? 0, digits: 2)) km, elevation gain \(Int((stats.historicalAvgGainM ?? 0).rounded())) m, duration \(Int((stats.historicalAvgDurationMinutes ?? 0).rounded())) min.
            Baseline fatigue \(Int((stats.historicalAvgFatigue ?? 0).rounded())), baseline difficulty \(Int((stats.historicalAvgDifficulty ?? 0).rounded())).
            Current distance change \(signedPercent(stats.distanceDeltaPercent)) and fatigue change \(signedValue(stats.fatigueDelta, digits: 0)).
            Personal best distance \(decimal(stats.personalBestDistanceKm ?? 0, digits: 2)) km and best gain \(Int((stats.personalBestGainM ?? 0).rounded())) m.
            """
        } else {
            historyText = "No historical sessions yet."
        }

        let terrainText = """
        Terrain split: climb \(Int(stats.climbPercent.rounded()))%, downhill \(Int(stats.downhillPercent.rounded()))%, technical \(Int(stats.technicalPercent.rounded()))%, flat \(Int(stats.flatPercent.rounded()))%.
        Dominant terrain: \(stats.dominantTerrain.rawValue).
        Effort by terrain index: climb \(signedValue(stats.climbEffort, digits: 1)), downhill \(signedValue(stats.downhillEffort, digits: 1)), technical \(signedValue(stats.technicalEffort, digits: 1)), flat \(signedValue(stats.flatEffort, digits: 1)).
        """

        let splitText = """
        First-half speed \(decimal(stats.firstHalfSpeed, digits: 2)) m/s vs second-half speed \(decimal(stats.secondHalfSpeed, digits: 2)) m/s.
        First-half effort \(decimal(stats.firstHalfEffort, digits: 1)) vs second-half effort \(decimal(stats.secondHalfEffort, digits: 1)).
        """

        let safetyText = """
        Safety flags: checkInDue=\(stats.safety.checkInDue), lowBattery=\(stats.safety.lowBattery), overFatigued=\(stats.safety.overFatigued), returnHomeEnergyRisk=\(stats.safety.returnHomeEnergyRisk).
        """

        switch style {
        case .detailed:
            return """
            You are analyzing one completed hike session.
            Output language must be English (United States).
            Return exactly 3 lines.
            Use strict format Title|Detail.
            Title max 4 words. Detail max 130 characters.
            No bullets, numbering, JSON, or extra text.

            Athlete profile:
            \(profileText)

            Current hike metrics:
            Duration \(Int(stats.durationMinutes.rounded())) min, distance \(decimal(stats.distanceKm, digits: 2)) km, elevation gain \(Int(stats.elevationGainM.rounded())) m.
            Average pace \(stats.averagePaceText), speed average \(decimal(stats.averageSpeed, digits: 2)) m/s, speed min \(decimal(stats.minSpeed, digits: 2)) m/s, speed max \(decimal(stats.maxSpeed, digits: 2)) m/s.
            Segment count \(stats.segmentCount), average slope \(decimal(stats.averageSlopePercent, digits: 1))%, steepest climb \(decimal(stats.steepestClimbPercent, digits: 1))%, steepest descent \(decimal(stats.steepestDescentPercent, digits: 1))%.
            Cadence average \(decimal(stats.averageCadence, digits: 2)), cadence max \(decimal(stats.maxCadence, digits: 2)).
            \(heartRateText)
            Trail difficulty \(Int(stats.trailDifficultyScore.rounded())), fatigue score \(Int(stats.fatigueScore.rounded())), energy used \(Int(stats.energyUsedPercent.rounded()))%, energy remaining \(Int(stats.energyRemainingPercent.rounded()))%.
            \(routeText)
            \(terrainText)
            \(splitText)
            \(safetyText)

            History baseline:
            \(historyText)

            Build exactly three actionable insights:
            1) pacing and effort management
            2) terrain handling technique
            3) recovery readiness for next 24 hours
            """
        case .compact:
            return """
            Reply only in English (United States). Return exactly 3 lines as Title|Detail.
            Profile: \(profileText)
            Hike: \(Int(stats.durationMinutes.rounded())) min, \(decimal(stats.distanceKm, digits: 2)) km, \(Int(stats.elevationGainM.rounded())) m gain, pace \(stats.averagePaceText), fatigue \(Int(stats.fatigueScore.rounded())), energy remaining \(Int(stats.energyRemainingPercent.rounded()))%, difficulty \(Int(stats.trailDifficultyScore.rounded())).
            Terrain: climb \(Int(stats.climbPercent.rounded()))%, downhill \(Int(stats.downhillPercent.rounded()))%, technical \(Int(stats.technicalPercent.rounded()))%, flat \(Int(stats.flatPercent.rounded()))%, dominant \(stats.dominantTerrain.rawValue), steepest climb \(decimal(stats.steepestClimbPercent, digits: 1))%.
            Splits: first-half speed \(decimal(stats.firstHalfSpeed, digits: 2)) vs second-half speed \(decimal(stats.secondHalfSpeed, digits: 2)) m/s.
            Route: \(routeText)
            \(heartRateText)
            History: \(historyText)
            Safety: \(safetyText)
            Make three insights: pacing, terrain, and recovery.
            """
        }
    }

    private func deterministicPostHikeInsights(from stats: PostHikeStats) -> [PerformanceInsight] {
        let speedChangePercent = percentChange(from: stats.firstHalfSpeed, to: stats.secondHalfSpeed)
        let effortRise = stats.secondHalfEffort - stats.firstHalfEffort

        let pacingDetail: String
        if speedChangePercent < -12 || effortRise > 8 {
            pacingDetail = "Late hike slowdown: speed \(signedPercent(speedChangePercent)) and effort +\(Int(effortRise.rounded())). Start climbs 10-15% easier."
        } else if speedChangePercent > 8 && effortRise <= 3 {
            pacingDetail = "Strong negative split. Speed rose \(signedPercent(speedChangePercent)) with stable effort, so pacing control was efficient."
        } else {
            pacingDetail = "Pacing was steady. Speed shift \(signedPercent(speedChangePercent)) and effort change \(signedValue(effortRise, digits: 0)); keep current opening pace."
        }

        let terrainLoad = max(stats.climbPercent, stats.downhillPercent, stats.technicalPercent, stats.flatPercent)
        let terrainDetail: String
        if stats.dominantTerrain == .climb {
            terrainDetail = "Climb-heavy load (\(Int(terrainLoad.rounded()))%). Steepest climb \(decimal(stats.steepestClimbPercent, digits: 1))%; shorten stride to protect late-stage energy."
        } else if stats.dominantTerrain == .downhill {
            terrainDetail = "Downhill-heavy load (\(Int(terrainLoad.rounded()))%). Peak descent \(decimal(stats.steepestDescentPercent, digits: 1))%; keep cadence high to reduce impact stress."
        } else if stats.dominantTerrain == .technical {
            terrainDetail = "Technical terrain dominated (\(Int(terrainLoad.rounded()))%). Maintain controlled foot placement before adding pace on rough segments."
        } else {
            terrainDetail = "Flat terrain led (\(Int(terrainLoad.rounded()))%). Use these sections to reset breathing before the next gradient change."
        }

        let riskFlags = [stats.safety.checkInDue, stats.safety.lowBattery, stats.safety.overFatigued, stats.safety.returnHomeEnergyRisk].filter { $0 }.count
        let recoveryDetail: String
        if stats.fatigueScore > 70 || stats.energyRemainingPercent < 30 || riskFlags > 0 {
            recoveryDetail = "Recovery priority: fatigue \(Int(stats.fatigueScore.rounded())) and energy \(Int(stats.energyRemainingPercent.rounded()))%. Plan hydration, food, and easy movement today."
        } else if let fatigueDelta = stats.fatigueDelta, fatigueDelta > 8 {
            recoveryDetail = "Fatigue is \(signedValue(fatigueDelta, digits: 0)) above your baseline. Add extra sleep and keep tomorrow's load easy."
        } else {
            recoveryDetail = "Readiness looks stable: fatigue \(Int(stats.fatigueScore.rounded())) with \(Int(stats.energyRemainingPercent.rounded()))% energy left. Normal recovery routine is enough."
        }

        return [
            PerformanceInsight(title: "Pacing", detail: String(pacingDetail.prefix(140))),
            PerformanceInsight(title: "Terrain", detail: String(terrainDetail.prefix(140))),
            PerformanceInsight(title: "Recovery", detail: String(recoveryDetail.prefix(140)))
        ]
    }

    private func cleanSingleLine(_ text: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func parseInsights(from text: String) -> [PerformanceInsight] {
        var insights: [PerformanceInsight] = []
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            let cleaned = stripListPrefix(from: line)
            guard !cleaned.isEmpty else { continue }
            if let parsed = parseInsightLine(cleaned) {
                insights.append(parsed)
            }
        }

        return Array(insights.prefix(3))
    }

    private func parseInsightLine(_ line: String) -> PerformanceInsight? {
        if let insight = insight(line, separatedBy: "|") { return insight }
        if let insight = insight(line, separatedBy: ":") { return insight }
        if let insight = insight(line, separatedBy: " - ") { return insight }
        return nil
    }

    private func insight(_ line: String, separatedBy separator: String) -> PerformanceInsight? {
        guard let range = line.range(of: separator) else { return nil }
        let title = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidInsightTitle(title), detail.count > 10 else { return nil }
        return PerformanceInsight(
            title: String(title.prefix(40)),
            detail: String(detail.prefix(140))
        )
    }

    private func fallbackInsights(from text: String) -> [PerformanceInsight] {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ")
        let sentences = collapsed
            .split(whereSeparator: isSentenceSeparator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }

        guard !sentences.isEmpty else { return [] }

        return Array(sentences.prefix(3).enumerated().map { index, sentence in
            PerformanceInsight(
                title: fallbackTitle(for: sentence, index: index),
                detail: String(sentence.prefix(140))
            )
        })
    }

    private func fallbackTitle(for sentence: String, index: Int) -> String {
        let lower = sentence.lowercased()
        if lower.contains("recover") || lower.contains("rest") || lower.contains("readiness") { return "Recovery" }
        if lower.contains("terrain") || lower.contains("climb") || lower.contains("downhill") { return "Terrain" }
        if lower.contains("pace") || lower.contains("fatigue") || lower.contains("effort") { return "Pacing" }
        let defaults = ["Pacing", "Terrain", "Recovery"]
        return defaults[min(index, defaults.count - 1)]
    }

    private func stripListPrefix(from line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)

        while let first = cleaned.first, first == "•" || first == "-" || first == "*" {
            cleaned.removeFirst()
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let firstSpace = cleaned.firstIndex(of: " ") {
            let token = cleaned[..<firstSpace]
            let isNumberedToken = token.contains(where: \.isNumber) && token.allSatisfy { character in
                character.isNumber || character == "." || character == ")" || character == "("
            }
            if isNumberedToken {
                cleaned = String(cleaned[cleaned.index(after: firstSpace)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return cleaned
    }

    private func isValidInsightTitle(_ title: String) -> Bool {
        !title.isEmpty && title.count <= 40
    }

    private func isSentenceSeparator(_ character: Character) -> Bool {
        character == "." || character == "!" || character == "?"
    }

    private func formattedPace(from speed: Double) -> String {
        guard speed > 0 else { return "n/a" }
        let secondsPerKm = 1000 / speed
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", locale: englishPOSIXLocale, minutes, seconds)
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func decimal(_ value: Double, digits: Int) -> String {
        switch digits {
        case 0:
            return String(format: "%.0f", locale: englishPOSIXLocale, value)
        case 1:
            return String(format: "%.1f", locale: englishPOSIXLocale, value)
        default:
            return String(format: "%.2f", locale: englishPOSIXLocale, value)
        }
    }

    private func signedPercent(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(Int(value.rounded()))%"
    }

    private func signedValue(_ value: Double?, digits: Int) -> String {
        guard let value else { return "n/a" }
        let prefix = value >= 0 ? "+" : ""
        return "\(prefix)\(decimal(value, digits: digits))"
    }

    private func percentChange(from baseline: Double, to current: Double) -> Double {
        guard baseline > 0 else { return 0 }
        return ((current - baseline) / baseline) * 100
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func modelLocaleSupport(for model: SystemLanguageModel) -> (
        supportsCurrent: Bool,
        supportsNormalized: Bool,
        hasRegionOverride: Bool,
        current: Locale,
        normalized: Locale
    ) {
        let currentLocale = Locale.current
        let normalizedIdentifier = normalizedLocaleIdentifier(from: currentLocale.identifier)
        let normalizedLocale = normalizedIdentifier == currentLocale.identifier
            ? currentLocale
            : Locale(identifier: normalizedIdentifier)
        let supportsCurrent = model.supportsLocale(currentLocale)
        let supportsNormalized = model.supportsLocale(normalizedLocale)
        let hasRegionOverride = hasRegionOverride(in: currentLocale.identifier)
        return (supportsCurrent, supportsNormalized, hasRegionOverride, currentLocale, normalizedLocale)
    }
#endif

    private func normalizedLocaleIdentifier(from identifier: String) -> String {
        var normalized = identifier
        if let atIndex = normalized.firstIndex(of: "@") {
            normalized = String(normalized[..<atIndex])
        }
        if let extensionRange = normalized.range(of: "-u-", options: [.regularExpression, .caseInsensitive]) {
            normalized = String(normalized[..<extensionRange.lowerBound])
        }
        return normalized
    }

    private func hasRegionOverride(in identifier: String) -> Bool {
        let lower = identifier.lowercased()
        if lower.contains("@rg=") {
            return true
        }
        return lower.range(of: "-u-.*-rg-", options: [.regularExpression]) != nil
    }
}
