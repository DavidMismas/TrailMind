import SwiftUI
import SwiftData

@main
struct TrailMindApp: App {
    private let modelContainer: ModelContainer
    private let container: AppContainer

    init() {
        let schema = Schema([PersistedHikeRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let swiftDataContainer = try ModelContainer(for: schema, configurations: [config])
            self.modelContainer = swiftDataContainer
            self.container = AppContainer(modelContext: swiftDataContainer.mainContext)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
        .modelContainer(modelContainer)
    }
}
