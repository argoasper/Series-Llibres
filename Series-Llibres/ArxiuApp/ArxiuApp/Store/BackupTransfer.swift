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

    /// "arxiu-2026-08-09"
    static var suggestedFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "arxiu-\(formatter.string(from: Date()))"
    }

    /// Llegeix un fitxer triat al selector de documents.
    /// Cal obrir i tancar l'àmbit de seguretat: els fitxers viuen fora del sandbox de l'app.
    static func read(from url: URL) throws -> Backup {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Backup.self, from: data)
    }
}
