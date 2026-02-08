import SwiftUI
import SwiftData

struct ContentView: View {
    let container: AppContainer
    @ObservedObject private var profileStore: UserProfileStore

    init(container: AppContainer) {
        self.container = container
        _profileStore = ObservedObject(wrappedValue: container.profileStore)
    }

    var body: some View {
        RootTabView(
            liveViewModel: container.liveHikeViewModel,
            postViewModel: container.postHikeViewModel,
            settingsViewModel: container.settingsViewModel,
            profileStore: container.profileStore
        )
        .fullScreenCover(isPresented: onboardingBinding) {
            ProfileOnboardingScreen { profile in
                container.profileStore.save(profile)
            }
            .interactiveDismissDisabled()
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { profileStore.needsOnboarding },
            set: { _ in }
        )
    }
}

#Preview {
    let schema = Schema([PersistedHikeRecord.self])
    let modelContainer = try! ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
    )

    return ContentView(container: AppContainer(modelContext: modelContainer.mainContext))
        .modelContainer(modelContainer)
}
