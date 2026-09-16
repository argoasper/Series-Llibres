import Foundation
import SwiftData

/// Carrega, un únic cop, les 355 fitxes i 132 llibres exportats de l'HTML.
enum SeedLoader {
    private static let flagKey = "arxiu_seeded_v1"

    /// Motiu pel qual l'arxiu ha quedat buit, per poder-ho explicar a l'usuari
    /// en lloc d'ensenyar-li una pantalla buida sense cap pista.
    private(set) static var seedFailure: String?

    static func seedIfNeeded(context: ModelContext, cloudEnabled: Bool = false) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        // Amb iCloud actiu i un compte iniciat, un dispositiu nou arrenca amb
        // el magatzem buit fins que arriba la sincronització: sembrar-lo aquí
        // faria que les 487 fitxes apareguessin per duplicat. Les dades vénen
        // del núvol (i, si no n'hi ha, sempre queda «Importa» al menú).
        if cloudEnabled, FileManager.default.ubiquityIdentityToken != nil {
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        // Si ja hi ha dades (per exemple després d'una reinstal·lació amb iCloud), no toquem res.
        let existing = (try? context.fetchCount(FetchDescriptor<LibraryItem>())) ?? 0
        guard existing == 0 else {
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        guard let url = Bundle.main.url(forResource: "SeedData", withExtension: "json") else {
            seedFailure = "No s'ha trobat SeedData.json dins de l'app."
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let backup = try JSONDecoder().decode(Backup.self, from: data)
            for item in backup.items() {
                context.insert(item)
            }
            try context.save()
            seedFailure = nil
            UserDefaults.standard.set(true, forKey: flagKey)
        } catch {
            seedFailure = "No s'ha pogut llegir SeedData.json: \(error.localizedDescription)"
        }
    }

    // MARK: - Substitució completa (importació)

    enum ImportError: LocalizedError {
        case failed(underlying: Error, safetyCopy: URL?)

        var errorDescription: String? {
            switch self {
            case .failed(let underlying, let safetyCopy):
                var text = "La importació ha fallat i s'ha desfet: \(underlying.localizedDescription)"
                if let safetyCopy {
                    text += "\n\nL'arxiu que hi havia abans és intacte i, a més, n'hi ha una còpia a:\n"
                    text += BackupTransfer.displayPath(safetyCopy)
                }
                return text
            }
        }
    }

    /// Substitueix tot el contingut per un backup importat.
    ///
    /// Abans d'esborrar res escriu una còpia automàtica de l'arxiu actual, i si
    /// qualsevol pas falla fa `rollback()` perquè no quedi l'arxiu a mitges.
    static func replaceAll(with backup: Backup, context: ModelContext) throws {
        let current = (try? context.fetch(FetchDescriptor<LibraryItem>())) ?? []
        let safetyCopy = current.isEmpty ? nil : try? BackupTransfer.writeSafetyCopy(items: current)

        do {
            try context.delete(model: LibraryItem.self)
            for item in backup.items() {
                context.insert(item)
            }
            try context.save()
        } catch {
            // Res del que hi ha en aquesta operació s'ha desat encara:
            // rollback() deixa el context tal com estava abans.
            context.rollback()
            throw ImportError.failed(underlying: error, safetyCopy: safetyCopy)
        }
    }
}
