import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

final class AppleIntelligenceNarratorService: AppleIntelligenceService {

    func liveInsight(from snapshot: LiveMetricsSnapshot, profile: UserProfile?) async -> String {
        let fallback = fallbackLiveInsight(from: snapshot)

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable, model.supportsLocale(Locale.current) else { return fallback }

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

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            print("[AI] postHike isAvailable=\(model.isAvailable) supportsLocale=\(model.supportsLocale(Locale.current)) availability=\(model.availability)")
            guard model.isAvailable, model.supportsLocale(Locale.current) else { return nil }

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

            let promptText = postHikePrompt(session: session, historical: historicalSessions, profile: profile)
            print("[AI] postHike full prompt:\n\(promptText)")

            do {
                let response = try await lmSession.respond(
                    to: promptText,
                    options: GenerationOptions(temperature: 0.25, maximumResponseTokens: 260)
                )
                let rawOutput = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                print("[AI] postHike raw output: \(rawOutput)")
                let parsed = parseInsights(from: rawOutput)
                if !parsed.isEmpty { return parsed }
                let fallback = fallbackInsights(from: rawOutput)
                print("[AI] postHike parsed=\(parsed.count) fallback=\(fallback.count)")
                return fallback.isEmpty ? nil : fallback
            } catch {
                print("[AI] postHike error: \(error)")
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
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
