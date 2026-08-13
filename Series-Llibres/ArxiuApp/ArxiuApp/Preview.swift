import SwiftUI
import SwiftData

/// Contenidor en memòria amb dades d'exemple per a les previews d'Xcode.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let schema = Schema([LibraryItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])

        let samples: [LibraryItem] = [
            LibraryItem(title: "Rooster", kind: .serie, status: .enCurs, year: 2025, season: 1),
            LibraryItem(title: "La Casa del Dragón", kind: .serie, status: .fet,
                        year: 2024, season: 3, completedAt: Date()),
            LibraryItem(title: "Dune: Part Two", kind: .peli, status: .fet,
                        year: 2024, completedAt: Date()),
            LibraryItem(title: "Anatomia d'una caiguda", kind: .peli, status: .pendent, year: 2023),
            LibraryItem(title: "El Futuro es Nuestro", kind: .llibre, status: .fet,
                        author: "Larry Collins", year: 2026, completedAt: Date()),
            LibraryItem(title: "Fundació", kind: .llibre, status: .enCurs, author: "Isaac Asimov", year: 1951)
        ]
        samples.forEach { container.mainContext.insert($0) }
        return container
    }()
}

#Preview("Inici") {
    HomeView()
        .modelContainer(PreviewData.container)
        .environment(ChangeHistory())
}

#Preview("Llista — Sèries") {
    NavigationStack {
        ItemListView(section: .kind(.serie))
    }
    .modelContainer(PreviewData.container)
    .environment(ChangeHistory())
}

#Preview("Formulari") {
    ItemFormView(mode: .create(kind: .serie))
        .modelContainer(PreviewData.container)
        .environment(ChangeHistory())
}
