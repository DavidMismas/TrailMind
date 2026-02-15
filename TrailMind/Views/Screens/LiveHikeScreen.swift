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

                        if viewModel.isTracking {
                            HStack(spacing: 10) {
                                Button {
                                    if viewModel.isPaused {
                                        viewModel.resumeHike()
                                    } else {
                                        viewModel.pauseHike()
                                    }
                                }
                                label: {
                                    Text(viewModel.isPaused ? "Resume" : "Pause")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.orange)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.stopHike()
                                }
                                label: {
                                    Text("Stop Hike")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            if viewModel.isPaused {
                                Text("Tracking paused. Time and fatigue are paused.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.white.opacity(0.72))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            Button {
                                viewModel.startHike()
                            }
                            label: {
                                Text("Start Hike")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(TrailTheme.accent)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

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
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Fuel Intake")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text(viewModel.estimatedCaloriesBurnedText)
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.78))
                            Text(viewModel.consumedCaloriesText)
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.78))
                            Text(viewModel.netEnergyText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white.opacity(0.86))

                            HStack(spacing: 8) {
                                quickFuelButton(label: "+80 kcal", calories: 80)
                                quickFuelButton(label: "+120 kcal", calories: 120)
                                quickFuelButton(label: "+200 kcal", calories: 200)
                            }

                            Text("Log snacks/gels/drinks during the hike to improve energy accuracy.")
                                .font(.footnote)
                                .foregroundStyle(Color.white.opacity(0.66))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .trailCard()

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

    private func quickFuelButton(label: String, calories: Double) -> some View {
        Button(label) {
            viewModel.logCalories(calories)
        }
        .buttonStyle(.bordered)
        .tint(TrailTheme.accent)
        .disabled(!viewModel.isTracking)
    }
}
