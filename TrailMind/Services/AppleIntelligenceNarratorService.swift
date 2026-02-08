import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleIntelligenceNarratorService: AppleIntelligenceService {
    func liveInsight(from snapshot: LiveMetricsSnapshot, profile: UserProfile?) async -> String {
        let fallback = fallbackLiveInsight(from: snapshot)

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { return fallback }

            let session = LanguageModelSession(model: model) {
                """
                You are a concise hiking coach.
                Use only provided metrics.
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
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { return nil }

            let lmSession = LanguageModelSession(model: model) {
                """
                You are a hiking performance analyst.
                Explain effort versus terrain using provided session data.
                Return exactly 3 lines in format: Title|Detail
                Title max 4 words.
                Detail max 120 characters.
                Avoid generic advice.
                """
            }

            do {
                let response = try await lmSession.respond(
                    to: postHikePrompt(session: session, historical: historicalSessions, profile: profile),
                    options: GenerationOptions(temperature: 0.25, maximumResponseTokens: 260)
                )
                let parsed = parseInsights(from: response.content)
                return parsed.isEmpty ? nil : parsed
            } catch {
                return nil
            }
        }
#endif

        return nil
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
        - distance: \(String(format: "%.2f", snapshot.distanceMeters / 1000)) km
        - elevation gain: \(Int(snapshot.elevationGain.rounded())) m
        - pace: \(paceText)
        - slope: \(String(format: "%.1f", snapshot.slopePercent))%
        - heart rate: \(heartRateText)
        - cadence: \(String(format: "%.2f", snapshot.cadence))
        - fatigue score: \(Int(snapshot.fatigue.score.rounded()))
        - energy remaining: \(Int((snapshot.fatigue.energyRemaining * 100).rounded()))%
        - trail difficulty: \(Int(snapshot.trailDifficultyScore.rounded()))
        - terrain: \(snapshot.terrain.rawValue)
        Give one immediate action for the next 2-5 minutes.
        """
    }

    private func postHikePrompt(session: HikeSession, historical: [HikeSession], profile: UserProfile?) -> String {
        let averageSpeed = session.duration > 0 ? session.totalDistance / session.duration : 0
        let paceText = formattedPace(from: averageSpeed)
        let maxSpeed = session.segments.map(\.averageSpeed).max() ?? 0
        let energyUsed = (1 - session.finalFatigue.energyRemaining) * 100

        let heartRateValues = session.segments.map(\.heartRate).filter { $0 > 0 }
        let avgHeartRate = heartRateValues.isEmpty ? nil : (heartRateValues.reduce(0, +) / Double(heartRateValues.count))
        let maxHeartRate = heartRateValues.max()

        let climbDuration = session.segments.filter { $0.terrain == .climb }.reduce(0) { $0 + $1.duration }
        let downhillDuration = session.segments.filter { $0.terrain == .downhill }.reduce(0) { $0 + $1.duration }
        let technicalDuration = session.segments.filter { $0.terrain == .technical }.reduce(0) { $0 + $1.duration }
        let flatDuration = session.segments.filter { $0.terrain == .flat }.reduce(0) { $0 + $1.duration }
        let totalTerrainDuration = max(1, climbDuration + downhillDuration + technicalDuration + flatDuration)

        let profileText: String
        if let profile {
            profileText = "Profile: age \(profile.age), weight \(Int(profile.weightKg))kg, height \(Int(profile.heightCm))cm, condition \(profile.condition.rawValue)."
        } else {
            profileText = "Profile: unavailable."
        }

        let historyText: String
        if historical.isEmpty {
            historyText = "History: no prior hikes."
        } else {
            let historicalAvgDistance = historical.map(\.totalDistance).reduce(0, +) / Double(historical.count)
            let historicalAvgGain = historical.map(\.totalElevationGain).reduce(0, +) / Double(historical.count)
            let historicalAvgFatigue = historical.map(\.finalFatigue.score).reduce(0, +) / Double(historical.count)
            historyText = "History avg: \(String(format: "%.2f", historicalAvgDistance / 1000)) km, \(Int(historicalAvgGain.rounded())) m gain, fatigue \(Int(historicalAvgFatigue.rounded()))."
        }

        let hrText: String
        if let avgHeartRate, let maxHeartRate {
            hrText = "Heart rate avg \(Int(avgHeartRate.rounded())) bpm, max \(Int(maxHeartRate.rounded())) bpm."
        } else {
            hrText = "Heart rate unavailable."
        }

        return """
        \(profileText)
        Hike summary:
        - duration: \(Int(session.duration / 60)) min
        - distance: \(String(format: "%.2f", session.totalDistance / 1000)) km
        - elevation gain: \(Int(session.totalElevationGain.rounded())) m
        - average pace: \(paceText)
        - max speed: \(String(format: "%.2f", maxSpeed)) m/s
        - trail difficulty: \(Int(session.trailDifficultyScore.rounded()))
        - final fatigue score: \(Int(session.finalFatigue.score.rounded()))
        - energy used: \(Int(energyUsed.rounded()))%
        - terrain time split:
          climb \(Int((climbDuration / totalTerrainDuration * 100).rounded()))%,
          downhill \(Int((downhillDuration / totalTerrainDuration * 100).rounded()))%,
          technical \(Int((technicalDuration / totalTerrainDuration * 100).rounded()))%,
          flat \(Int((flatDuration / totalTerrainDuration * 100).rounded()))%
        \(hrText)
        \(historyText)
        Generate 3 insights:
        1) pacing/effort management
        2) terrain handling
        3) recovery/readiness
        """
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
            let cleaned = line
                .replacingOccurrences(of: "•", with: "")
                .replacingOccurrences(of: "-", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let pipeParts = cleaned.split(separator: "|", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if pipeParts.count == 2 {
                insights.append(PerformanceInsight(
                    title: String(pipeParts[0].prefix(40)),
                    detail: String(pipeParts[1].prefix(140))
                ))
                continue
            }

            let colonParts = cleaned.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if colonParts.count == 2 {
                insights.append(PerformanceInsight(
                    title: String(colonParts[0].prefix(40)),
                    detail: String(colonParts[1].prefix(140))
                ))
            }
        }

        return Array(insights.prefix(3))
    }

    private func formattedPace(from speed: Double) -> String {
        guard speed > 0 else { return "n/a" }
        let secondsPerKm = 1000 / speed
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
