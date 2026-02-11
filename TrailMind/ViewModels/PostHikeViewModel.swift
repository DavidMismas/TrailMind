import Foundation
import Combine
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class PostHikeViewModel: ObservableObject {
    @Published private(set) var hikes: [HikeSession] = []
    @Published private(set) var premiumTier: PremiumTier = .free
    @Published private(set) var aiInsightsByHikeID: [UUID: [PerformanceInsight]] = [:]
    @Published private(set) var generatingAIInsightsFor: Set<UUID> = []
    @Published private(set) var aiInsightsUnavailableFor: Set<UUID> = []
    @Published private(set) var aiUnavailableReasonByHikeID: [UUID: String] = [:]

    private let sessionStore: HikeSessionStore
    private let analysisService: PostHikeAnalysisService
    private let gpxService: GPXExportService
    private let aiService: AppleIntelligenceService
    private let profileStore: UserProfileStore
    private var cancellables = Set<AnyCancellable>()

    init(
        sessionStore: HikeSessionStore,
        analysisService: PostHikeAnalysisService,
        gpxService: GPXExportService,
        premiumService: PremiumPurchaseService,
        aiService: AppleIntelligenceService,
        profileStore: UserProfileStore
    ) {
        self.sessionStore = sessionStore
        self.analysisService = analysisService
        self.gpxService = gpxService
        self.aiService = aiService
        self.profileStore = profileStore

        sessionStore.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                guard let self else { return }
                hikes = sessions

                let validIDs = Set(sessions.map(\.id))
                aiInsightsByHikeID = aiInsightsByHikeID.filter { validIDs.contains($0.key) }
                generatingAIInsightsFor = generatingAIInsightsFor.filter { validIDs.contains($0) }
                aiInsightsUnavailableFor = aiInsightsUnavailableFor.filter { validIDs.contains($0) }
                aiUnavailableReasonByHikeID = aiUnavailableReasonByHikeID.filter { validIDs.contains($0.key) }
            }
            .store(in: &cancellables)

        premiumService.tierPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tier in
                self?.premiumTier = tier
            }
            .store(in: &cancellables)
    }

    func hike(for hikeID: UUID) -> HikeSession? {
        hikes.first { $0.id == hikeID }
    }

    func report(for hikeID: UUID) -> PostHikeReport? {
        guard let session = hike(for: hikeID) else { return nil }
        let historical = hikes.filter { $0.id != hikeID }
        let base = analysisService.buildReport(from: session, historicalSessions: historical)

        guard let aiInsights = aiInsightsByHikeID[hikeID], !aiInsights.isEmpty else {
            return base
        }

        return PostHikeReport(
            insights: aiInsights,
            recovery: base.recovery,
            fatigueToleranceTrend: base.fatigueToleranceTrend,
            climbEfficiency: base.climbEfficiency,
            terrainAdaptation: base.terrainAdaptation
        )
    }

    func renameHike(hikeID: UUID, newName: String) {
        sessionStore.rename(sessionID: hikeID, newName: newName)
    }

    func exportGPX(for hikeID: UUID) throws -> URL {
        guard let session = hike(for: hikeID) else {
            throw GPXExportError.emptyRoute
        }
        return try gpxService.export(session: session)
    }

    func requestAIInsights(for hikeID: UUID) {
        guard aiInsightsByHikeID[hikeID] == nil else { return }
        guard !generatingAIInsightsFor.contains(hikeID) else { return }
        guard let session = hike(for: hikeID) else { return }

        aiInsightsUnavailableFor.remove(hikeID)
        aiUnavailableReasonByHikeID.removeValue(forKey: hikeID)
        generatingAIInsightsFor.insert(hikeID)
        let historical = hikes.filter { $0.id != hikeID }
        let profile = profileStore.profile

        Task {
            let generated = await aiService.postHikeInsights(
                for: session,
                historicalSessions: historical,
                profile: profile
            )
            await MainActor.run {
                if let generated, !generated.isEmpty {
                    aiInsightsByHikeID[hikeID] = generated
                    aiInsightsUnavailableFor.remove(hikeID)
                    aiUnavailableReasonByHikeID.removeValue(forKey: hikeID)
                } else {
                    aiInsightsUnavailableFor.insert(hikeID)
                    aiUnavailableReasonByHikeID[hikeID] = currentAIUnavailableReason()
                }
                generatingAIInsightsFor.remove(hikeID)
            }
        }
    }

    func isGeneratingAIInsights(for hikeID: UUID) -> Bool {
        generatingAIInsightsFor.contains(hikeID)
    }

    func isAIUnavailable(for hikeID: UUID) -> Bool {
        aiInsightsUnavailableFor.contains(hikeID)
    }

    func aiUnavailableReason(for hikeID: UUID) -> String? {
        aiUnavailableReasonByHikeID[hikeID]
    }

    private func currentAIUnavailableReason() -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default

            switch model.availability {
            case .available:
                if !model.supportsLocale() {
                    return "Current system language is not supported by Apple Intelligence on this device."
                }
                // supportsLocale() may still pass when Locale.current carries Unicode extensions
                // like @rg= (region override), which FoundationModels rejects at session time.
                // Check for this known iOS 26 beta issue.
                if Locale.current.identifier.contains("@") {
                    return "Your device Region setting is causing a conflict with Apple Intelligence. Go to Settings → General → Language & Region → Region and set it to United States (or any English-speaking region)."
                }
                return "Apple Intelligence responded with no usable output. Try again."
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible:
                    return "This iPhone is not eligible for on-device Apple Intelligence."
                case .appleIntelligenceNotEnabled:
                    return "Apple Intelligence is disabled in Settings."
                case .modelNotReady:
                    return "Apple Intelligence model is still downloading or preparing."
                @unknown default:
                    return "Apple Intelligence is currently unavailable for an unknown system reason."
                }
            }
        }
#endif
        return "Apple Intelligence runtime is unavailable on this build."
    }
}
