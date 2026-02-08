import SwiftUI

struct SettingsScreen: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                TrailTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        permissionsCard
                        planCard

                        PremiumFeatureCardView(
                            title: "Live Terrain Intelligence",
                            description: "AI pacing advice by slope and movement pattern.",
                            enabled: viewModel.premiumTier.hasTerrainIntelligence
                        )
                        PremiumFeatureCardView(
                            title: "Energy Prediction",
                            description: "Estimate if current load allows safe return.",
                            enabled: viewModel.premiumTier.hasEnergyPrediction
                        )
                        PremiumFeatureCardView(
                            title: "Recovery Model",
                            description: "Muscle load, recovery time, and readiness score.",
                            enabled: viewModel.premiumTier.hasRecoveryModel
                        )

                        if viewModel.premiumTier == .free {
                            Button(viewModel.isPurchasing ? "Purchasing..." : "Unlock Premium") {
                                viewModel.purchasePremium()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(TrailTheme.accent)
                            .disabled(viewModel.isPurchasing)
                        }

                        if !viewModel.purchaseStatus.isEmpty {
                            Text(viewModel.purchaseStatus)
                                .font(.footnote)
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
                .foregroundStyle(.white)

            Toggle("Location Tracking", isOn: Binding(
                get: { viewModel.locationEnabled },
                set: { viewModel.locationToggleChanged($0) }
            ))
            .tint(TrailTheme.accent)

            Toggle("Background Location", isOn: Binding(
                get: { viewModel.backgroundLocationEnabled },
                set: { viewModel.backgroundLocationToggleChanged($0) }
            ))
            .tint(TrailTheme.accent)

            Toggle("Fitness (Health + Motion)", isOn: Binding(
                get: { viewModel.fitnessEnabled },
                set: { viewModel.fitnessToggleChanged($0) }
            ))
            .tint(TrailTheme.accent)

            Text("Turning a toggle OFF opens iOS Settings because permissions are managed by the system.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.68))

            Button("Open System Settings") {
                viewModel.openSystemSettings()
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .foregroundStyle(.white)
        .trailCard()
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan")
                .font(.headline)
                .foregroundStyle(.white)
            Text(viewModel.premiumTier == .premium ? "Premium Lifetime" : "Free")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Premium is a one-time purchase.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trailCard()
    }
}
