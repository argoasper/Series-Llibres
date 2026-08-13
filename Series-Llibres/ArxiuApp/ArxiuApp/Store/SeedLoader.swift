import Foundation
import SwiftData

/// Carrega, un únic cop, les 355 fitxes i 132 llibres exportats de l'HTML.
enum SeedLoader {
    private static let flagKey = "arxiu_seeded_v1"

    static func seedIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        // Si ja hi ha dades (per exemple després d'una reinstal·lació amb iCloud), no toquem res.
        let existing = (try? context.fetchCount(FetchDescriptor<LibraryItem>())) ?? 0
        guard existing == 0 else {
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        guard let url = Bundle.main.url(forResource: "SeedData", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let backup = try? JSONDecoder().decode(Backup.self, from: data) else {
            return
        }

        for item in backup.items() {
            context.insert(item)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    /// Substitueix tot el contingut per un backup importat.
    static func replaceAll(with backup: Backup, context: ModelContext) throws {
        try context.delete(model: LibraryItem.self)
        for item in backup.items() {
            context.insert(item)
        }
        try context.save()
    }
}
