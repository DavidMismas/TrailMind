import SwiftUI

struct LiveHikeScreen: View {
    @ObservedObject var viewModel: LiveHikeViewModel
    @State private var isShowingFullMap = false

    var body: some View {
        NavigationStack {
            ZStack {
                TrailTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        RouteMapView(
                            route: viewModel.route,
                            isTracking: viewModel.isTracking,
                            onExpand: { isShowingFullMap = true }
                        )

                        Button {
                            if viewModel.isTracking {
                                viewModel.stopHike()
                            } else {
                                viewModel.startHike()
                            }
                        }
                        label: {
                            Text(viewModel.isTracking ? "Stop Hike" : "Start Hike")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.isTracking ? Color.red : TrailTheme.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        HStack {
                            MetricTileView(
                                title: "Time",
                                value: Formatting.duration(viewModel.elapsed),
                                footnote: "active hike"
                            )
                            MetricTileView(
                                title: "Trail Difficulty",
                                value: "\(Int(viewModel.trailDifficultyScore))",
                                footnote: "terrain + effort",
                                tint: TrailTheme.warning
                            )
                        }

                        HStack {
                            MetricTileView(
                                title: "Pace",
                                value: Formatting.pace(from: viewModel.speed),
                                footnote: "current"
                            )
                            MetricTileView(
                                title: "Heart Rate",
                                value: viewModel.heartRateDisplayValue,
                                footnote: viewModel.heartRateFootnote
                            )
                        }

                        AltitudeProfileView(route: viewModel.route)

                        HStack {
                            MetricTileView(
                                title: "Elevation Gain",
                                value: Formatting.meters(viewModel.totalElevationGain),
                                footnote: "total"
                            )
                            MetricTileView(
                                title: "Live Altitude",
                                value: Formatting.meters(viewModel.currentAltitude),
                                footnote: "current"
                            )
                        }

                        FatigueCardView(fatigue: viewModel.fatigueState)
                        SafetyCardView(state: viewModel.safetyState)
                        CheckInCardView(isDue: viewModel.safetyState.checkInDue, action: viewModel.markSafetyCheckIn)
                        TerrainInsightCardView(
                            terrain: viewModel.terrain,
                            pacingAdvice: viewModel.pacingAdvice,
                            safetyHint: viewModel.terrainSafetyHint,
                            aiInsight: viewModel.aiInsight,
                            isPremium: viewModel.premiumTier.hasTerrainIntelligence
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Energy Forecast")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(viewModel.energyToGoalText)
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.76))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .trailCard()
                    }
                    .padding()
                }
            }
            .navigationTitle("Main Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .fullScreenCover(isPresented: $isShowingFullMap) {
                FullScreenMapScreen(route: viewModel.route)
            }
        }
    }
}
