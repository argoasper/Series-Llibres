import SwiftUI
import SwiftData

@main
struct ArxiuApp: App {
    @State private var history = ChangeHistory()

    private let container: ModelContainer = {
        let schema = Schema([LibraryItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No s'ha pogut crear el contenidor de SwiftData: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(history)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
