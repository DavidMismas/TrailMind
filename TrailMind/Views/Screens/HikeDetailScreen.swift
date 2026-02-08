import SwiftUI

struct HikeDetailScreen: View {
    @ObservedObject var viewModel: PostHikeViewModel
    let hikeID: UUID

    @State private var renameDraft = ""
    @State private var showRename = false
    @State private var gpxURL: URL?
    @State private var exportError = ""

    var body: some View {
        Group {
            if let session = viewModel.hike(for: hikeID), let report = viewModel.report(for: hikeID) {
                ScrollView {
                    VStack(spacing: 14) {
                        HStack {
                            MetricTileView(
                                title: "Distance",
                                value: Formatting.km(from: session.totalDistance),
                                footnote: "total"
                            )
                            MetricTileView(
                                title: "Elevation",
                                value: Formatting.meters(session.totalElevationGain),
                                footnote: "gain"
                            )
                        }

                        HStack {
                            MetricTileView(
                                title: "Duration",
                                value: Formatting.duration(session.duration),
                                footnote: "moving time"
                            )
                            MetricTileView(
                                title: "Final Fatigue",
                                value: "\(Int(session.finalFatigue.score))",
                                footnote: "session end",
                                tint: .orange
                            )
                        }

                        HStack {
                            MetricTileView(
                                title: "Trail Score",
                                value: "\(Int(session.trailDifficultyScore))",
                                footnote: "effort + terrain"
                            )
                            MetricTileView(
                                title: "Segments",
                                value: "\(session.segments.count)",
                                footnote: "pace blocks"
                            )
                        }

                        if viewModel.isGeneratingAIInsights(for: hikeID) {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(.white)
                                Text("Generating AI insights from your hike data...")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .trailCard()
                        }

                        if viewModel.isAIUnavailable(for: hikeID) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Apple Intelligence is unavailable, so this report uses rule-based insights.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.white.opacity(0.76))

                                if let reason = viewModel.aiUnavailableReason(for: hikeID), !reason.isEmpty {
                                    Text(reason)
                                        .font(.footnote)
                                        .foregroundStyle(Color.orange.opacity(0.9))
                                }

                                Button("Retry AI Insights") {
                                    viewModel.requestAIInsights(for: hikeID)
                                }
                                .buttonStyle(.bordered)
                                .tint(TrailTheme.accent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .trailCard()
                        }

                        InsightsListView(insights: report.insights)

                        if viewModel.premiumTier.hasRecoveryModel {
                            RecoveryCardView(report: report.recovery)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Progression")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Fatigue tolerance: \(report.fatigueToleranceTrend)")
                                Text("Climb efficiency: \(Int(report.climbEfficiency))")
                                Text("Terrain adaptation: \(Int(report.terrainAdaptation))")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .trailCard()
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Data")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Button("Export GPX") {
                                do {
                                    gpxURL = try viewModel.exportGPX(for: hikeID)
                                    exportError = ""
                                } catch {
                                    exportError = "GPX export needs recorded route points."
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(TrailTheme.accent)

                            if let gpxURL {
                                ShareLink(item: gpxURL) {
                                    Label("Share GPX", systemImage: "square.and.arrow.up")
                                }
                                .foregroundStyle(.white)
                            }

                            if !exportError.isEmpty {
                                Text(exportError)
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .trailCard()
                    }
                    .padding()
                }
                .background {
                    TrailTheme.background.ignoresSafeArea()
                }
                .navigationTitle(session.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Rename") {
                            renameDraft = session.displayName
                            showRename = true
                        }
                    }
                }
                .alert("Rename Hike", isPresented: $showRename) {
                    TextField("Hike name", text: $renameDraft)
                    Button("Cancel", role: .cancel) {}
                    Button("Save") {
                        viewModel.renameHike(hikeID: hikeID, newName: renameDraft)
                    }
                }
                .task(id: hikeID) {
                    viewModel.requestAIInsights(for: hikeID)
                }
            } else {
                ContentUnavailableView("Hike Missing", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
