import SwiftUI

struct RootTabView: View {
    @ObservedObject var liveViewModel: LiveHikeViewModel
    @ObservedObject var postViewModel: PostHikeViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var profileStore: UserProfileStore

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

            PersonalProfileScreen(profileStore: profileStore)
                .tabItem {
                    Label("Personal", systemImage: "person.fill")
                }

            SettingsScreen(viewModel: settingsViewModel)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .tint(TrailTheme.accent)
    }
}
