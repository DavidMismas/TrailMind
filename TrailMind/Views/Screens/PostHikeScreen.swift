import SwiftUI

struct PostHikeScreen: View {
    @ObservedObject var viewModel: PostHikeViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                TrailTheme.background
                    .ignoresSafeArea()

                if viewModel.hikes.isEmpty {
                    ContentUnavailableView(
                        "No Hikes Yet",
                        systemImage: "figure.hiking",
                        description: Text("Finish a hike to get saved analysis history.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.hikes) { hike in
                                NavigationLink(value: hike.id) {
                                    HikeListRow(session: hike)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: UUID.self) { hikeID in
                HikeDetailScreen(viewModel: viewModel, hikeID: hikeID)
            }
        }
    }
}

private struct HikeListRow: View {
    let session: HikeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Text(session.startedAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.68))

            HStack {
                Label(Formatting.km(from: session.totalDistance), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                Label(Formatting.meters(session.totalElevationGain), systemImage: "mountain.2")
                Label("\(Int(session.finalFatigue.score))", systemImage: "heart.fill")
            }
            .font(.caption)
            .foregroundStyle(Color.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .trailCard()
    }
}
