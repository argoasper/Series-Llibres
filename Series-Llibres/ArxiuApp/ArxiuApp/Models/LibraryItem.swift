import Foundation
import SwiftData

/// Model únic per a sèries, pel·lícules i llibres.
///
/// Totes les propietats tenen valor per defecte i les relacions són opcionals:
/// és el requisit de SwiftData per poder afegir camps nous (com `season` o
/// `completedAt`) sense trencar les bases de dades ja existents al dispositiu.
@Model
final class LibraryItem {
    var uid: UUID = UUID()
    var title: String = ""
    var author: String?
    var year: Int?
    var season: Int?

    /// Guardem els enums com a text: així el fitxer de la base de dades és
    /// llegible i la importació des del JSON de l'HTML és directa.
    var kindRaw: String = MediaKind.serie.rawValue
    var statusRaw: String = ItemStatus.pendent.rawValue

    /// Mes i any en què es va acabar (es mostra com a YYYY/MM).
    var completedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Metadades externes (OMDb per a sèries i pel·lícules, Google Books per a llibres).
    var ratingText: String?
    var genre: String?
    var plot: String?
    var imdbId: String?
    var publisher: String?
    var infoLink: String?

    init(
        uid: UUID = UUID(),
        title: String,
        kind: MediaKind,
        status: ItemStatus = .pendent,
        author: String? = nil,
        year: Int? = nil,
        season: Int? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.uid = uid
        self.title = title
        self.kindRaw = kind.rawValue
        self.statusRaw = status.rawValue
        self.author = author
        self.year = year
        self.season = season
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    // MARK: - Enums

    var kind: MediaKind {
        get { MediaKind(rawValue: kindRaw) ?? .serie }
        set { kindRaw = newValue.rawValue }
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .pendent }
        set { statusRaw = newValue.rawValue }
    }

    // MARK: - Derivats

    var statusLabel: String { status.label(for: kind) }

    /// "2026/08" o `nil` si encara no s'ha acabat.
    var completedLabel: String? { Formatters.yearMonthString(completedAt) }

    /// "T3" per a la insígnia de temporada de la fila.
    var seasonBadge: String? {
        guard kind.hasSeason, let season, season > 0 else { return nil }
        return "T\(season)"
    }

    var subtitleLine: String? {
        var parts: [String] = []
        if let author, !author.isEmpty { parts.append(author) }
        if let completedLabel { parts.append(completedLabel) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var externalURL: URL? {
        switch kind {
        case .serie, .peli:
            if let imdbId, !imdbId.isEmpty {
                return URL(string: "https://www.imdb.com/title/\(imdbId)/")
            }
            let q = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://www.imdb.com/find/?q=\(q)")
        case .llibre:
            if let infoLink, let url = URL(string: infoLink) { return url }
            let raw = title + (author.map { " " + $0 } ?? "")
            let q = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://www.goodreads.com/search?q=\(q)")
        }
    }

    var externalName: String { kind == .llibre ? "Goodreads" : "IMDb" }

    // MARK: - Mutacions

    /// Canvia l'estat i manté `completedAt` coherent:
    /// en marcar com a fet s'omple sol amb el mes actual, i en desmarcar-lo s'esborra.
    func apply(status newStatus: ItemStatus, now: Date = Date()) {
        status = newStatus
        if newStatus == .fet {
            if completedAt == nil { completedAt = now }
        } else {
            completedAt = nil
        }
        updatedAt = now
    }
}
