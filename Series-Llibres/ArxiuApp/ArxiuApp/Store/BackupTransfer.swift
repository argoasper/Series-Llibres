import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Document JSON per als diàlegs d'importar i exportar.
/// El contingut és exactament el format que exportava l'HTML original:
/// { "media": [...], "books": [...] }, així els fitxers són intercanviables.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    /// Serialitza l'arxiu sencer a JSON llegible.
    init(items: [LibraryItem]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.data = try encoder.encode(Backup(items: items))
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum BackupTransfer {

    /// Nom fix per a la còpia de seguretat (la data ja queda registrada
    /// als detalls/metadades del fitxer, no cal repetir-la al nom).
    static var suggestedFilename: String {
        "Series-Llibres-Backup"
    }

    /// Llegeix un fitxer triat al selector de documents.
    /// Cal obrir i tancar l'àmbit de seguretat: els fitxers viuen fora del sandbox de l'app.
    static func read(from url: URL) throws -> Backup {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Backup.self, from: data)
    }

    // MARK: - Xarxa de seguretat

    /// Carpeta "Copies-automatiques" dins dels Documents de l'app.
    /// Amb `UIFileSharingEnabled` activat, es veu des de l'app Fitxers.
    static var safetyFolder: URL {
        get throws {
            let documents = try FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true
            )
            let folder = documents.appendingPathComponent("Copies-automatiques", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }
    }

    /// Escriu una còpia de tot l'arxiu ABANS d'una operació destructiva.
    /// Retorna la ruta perquè es pugui ensenyar a l'usuari si res va malament.
    @discardableResult
    static func writeSafetyCopy(items: [LibraryItem], reason: String = "abans-dimportar") throws -> URL {
        let stamp = Formatters.fileStamp.string(from: Date())
        let url = try safetyFolder.appendingPathComponent("\(reason)-\(stamp).json")
        try BackupDocument(items: items).data.write(to: url, options: .atomic)
        pruneSafetyCopies()
        return url
    }

    /// Deixa només les 10 còpies automàtiques més recents.
    private static func pruneSafetyCopies() {
        guard let folder = try? safetyFolder,
              let files = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }

        let sorted = files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
        for old in sorted.dropFirst(10) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    /// Text curt per ensenyar a l'usuari on ha quedat la còpia.
    static func displayPath(_ url: URL) -> String {
        "Fitxers → A la meva iPhone → Sèries-Pel·lícules-Llibres → Copies-automatiques → \(url.lastPathComponent)"
    }
}
