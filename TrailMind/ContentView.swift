import SwiftUI
import SwiftData

struct ContentView: View {
    let container: AppContainer

    var body: some View {
        RootTabView(
            liveViewModel: container.liveHikeViewModel,
            postViewModel: container.postHikeViewModel,
            settingsViewModel: container.settingsViewModel
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
