import Foundation
import Combine

@MainActor
final class PostHikeViewModel: ObservableObject {
    @Published private(set) var hikes: [HikeSession] = []
    @Published private(set) var premiumTier: PremiumTier = .free

    private let sessionStore: HikeSessionStore
    private let analysisService: PostHikeAnalysisService
    private let gpxService: GPXExportService
    private var cancellables = Set<AnyCancellable>()

    init(
        sessionStore: HikeSessionStore,
        analysisService: PostHikeAnalysisService,
        gpxService: GPXExportService,
        premiumService: PremiumPurchaseService
    ) {
        self.sessionStore = sessionStore
        self.analysisService = analysisService
        self.gpxService = gpxService

        sessionStore.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.hikes = sessions
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
        return analysisService.buildReport(from: session, historicalSessions: historical)
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
}
