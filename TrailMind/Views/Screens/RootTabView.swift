import SwiftUI

struct RootTabView: View {
    @ObservedObject var liveViewModel: LiveHikeViewModel
    @ObservedObject var postViewModel: PostHikeViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel

    var body: some View {
        TabView {
            LiveHikeScreen(viewModel: liveViewModel)
                .tabItem {
                    Label("Main", systemImage: "map.fill")
                }

            PostHikeScreen(viewModel: postViewModel)
                .tabItem {
                    Label("Analysis", systemImage: "list.bullet.rectangle")
                }

            SettingsScreen(viewModel: settingsViewModel)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .tint(TrailTheme.accent)
    }
}
