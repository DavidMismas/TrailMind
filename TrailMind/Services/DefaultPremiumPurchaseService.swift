import Foundation
import Combine

enum PremiumPurchaseError: Error {
    case failed
}

final class DefaultPremiumPurchaseService: PremiumPurchaseService {
    private let key = "trailmind.premium.unlocked"
    private let subject: CurrentValueSubject<PremiumTier, Never>

    init(defaults: UserDefaults = .standard) {
#if DEBUG
        let initialTier: PremiumTier = .premium
#else
        let unlocked = defaults.bool(forKey: key)
        let initialTier: PremiumTier = unlocked ? .premium : .free
#endif
        subject = CurrentValueSubject(initialTier)
    }

    var tierPublisher: AnyPublisher<PremiumTier, Never> {
        subject.eraseToAnyPublisher()
    }

    var currentTier: PremiumTier {
        subject.value
    }

    func purchaseLifetime() async throws {
        try await Task.sleep(for: .milliseconds(400))
        UserDefaults.standard.set(true, forKey: key)
        subject.send(.premium)
    }
}
