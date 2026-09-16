import Foundation

/// Format exacte del backup que exporta l'HTML: { "media": [...], "books": [...] }.
/// Serveix tant per llegir el fitxer llavor com per importar i exportar des de l'app.
///
/// Els camps `uid` i `createdAt` són afegits per l'app: els lectors antics
/// (l'HTML original) simplement els ignoren, així que la compatibilitat es manté.
struct Backup: Codable {
    var media: [MediaRecord] = []
    var books: [BookRecord] = []
    var exportedAt: String?

    struct MediaRecord: Codable {
        var id: Int?
        var uid: String?           // afegit per l'app
        var title: String
        var year: Int?
        var type: String?          // "serie" | "peli"
        var status: String?        // "pendent" | "veient" | "vist"
        var season: Int?           // afegit per l'app
        var completedAt: String?   // "YYYY/MM", afegit per l'app
        var createdAt: String?     // ISO 8601, afegit per l'app
        var omdb: OMDbRecord?
    }

    struct BookRecord: Codable {
        var id: Int?
        var uid: String?           // afegit per l'app
        var title: String
        var author: String?
        var year: Int?
        var status: String?        // "pendent" | "llegint" | "llegit"
        var completedAt: String?
        var createdAt: String?     // ISO 8601, afegit per l'app
        var gbooks: GBooksRecord?
    }

    struct OMDbRecord: Codable {
        var rating: String?
        var genre: String?
        var plot: String?
        var imdbId: String?

        var isEmpty: Bool {
            rating == nil && genre == nil && plot == nil && imdbId == nil
        }
    }

    struct GBooksRecord: Codable {
        var publisher: String?
        var publishedDate: String?
        var description: String?
        var infoLink: String?

        var isEmpty: Bool {
            publisher == nil && publishedDate == nil && description == nil && infoLink == nil
        }
    }

    var count: Int { media.count + books.count }
}

// MARK: - Estats: text del JSON <-> ItemStatus
//
// L'HTML feia servir dos vocabularis separats (veient/vist per a sèries i
// pel·lícules, pendent/llegit per a llibres). Els tres estats de l'app hi han
// de caber SENCERS en totes dues direccions: si l'exportació només escriu dos
// valors, un cicle exportar -> importar canvia l'estat de les fitxes.

extension ItemStatus {
    /// Text que es desa al JSON per a aquest estat i aquest tipus de fitxa.
    func backupValue(for kind: MediaKind) -> String {
        switch (self, kind) {
        case (.pendent, _):       return "pendent"
        case (.enCurs, .llibre):  return "llegint"
        case (.enCurs, _):        return "veient"
        case (.fet, .llibre):     return "llegit"
        case (.fet, _):           return "vist"
        }
    }

    /// Estat corresponent a un text del JSON. `nil` vol dir "el JSON no ho deia".
    static func fromBackup(_ raw: String?, kind: MediaKind) -> ItemStatus? {
        switch raw?.trimmingCharacters(in: .whitespaces).lowercased() {
        case "pendent", "pending":        return .pendent
        case "veient", "llegint", "encurs", "en curs", "watching", "reading":
                                          return .enCurs
        case "vist", "llegit", "fet", "watched", "read":
                                          return .fet
        default:                          return nil
        }
    }
}

// MARK: - JSON de l'HTML -> LibraryItem

extension Backup {
    /// Detecta "(T3)" o "(t3)" al títol, com als registres que venen del Numbers original.
    private static let seasonPattern = try! NSRegularExpression(pattern: #"\(\s*[Tt]\s*(\d{1,2})\s*\)"#)

    static func season(inTitle title: String) -> Int? {
        let range = NSRange(title.startIndex..., in: title)
        guard let match = seasonPattern.firstMatch(in: title, range: range),
              let r = Range(match.range(at: 1), in: title) else { return nil }
        return Int(title[r])
    }

    func items() -> [LibraryItem] {
        var result: [LibraryItem] = []

        for record in media {
            let kind: MediaKind = (record.type == "peli") ? .peli : .serie
            // Per a sèries i pel·lícules, l'HTML no tenia "pendent": si el JSON
            // no diu res, es tracta com a pendent (és el que feia l'app abans).
            let status = ItemStatus.fromBackup(record.status, kind: kind) ?? .pendent

            let item = LibraryItem(
                uid: record.uid.flatMap(UUID.init(uuidString:)) ?? UUID(),
                title: record.title,
                kind: kind,
                status: status,
                year: record.year,
                season: record.season ?? (kind == .serie ? Backup.season(inTitle: record.title) : nil),
                completedAt: record.completedAt.flatMap(Formatters.date(fromYearMonth:)),
                createdAt: record.createdAt.flatMap(Formatters.iso.date(from:)) ?? Date()
            )
            if let omdb = record.omdb {
                item.ratingText = omdb.rating
                item.genre = omdb.genre
                item.plot = omdb.plot
                item.imdbId = omdb.imdbId
            }
            result.append(item)
        }

        for record in books {
            // L'HTML tractava per defecte els llibres com a llegits.
            let status = ItemStatus.fromBackup(record.status, kind: .llibre) ?? .fet

            let item = LibraryItem(
                uid: record.uid.flatMap(UUID.init(uuidString:)) ?? UUID(),
                title: record.title,
                kind: .llibre,
                status: status,
                author: record.author,
                year: record.year,
                completedAt: record.completedAt.flatMap(Formatters.date(fromYearMonth:)),
                createdAt: record.createdAt.flatMap(Formatters.iso.date(from:)) ?? Date()
            )
            if let g = record.gbooks {
                item.publisher = g.publisher
                item.plot = g.description
                item.infoLink = g.infoLink
            }
            result.append(item)
        }

        return result
    }
}

// MARK: - LibraryItem -> JSON (exportació compatible amb l'HTML)

extension Backup {
    init(items: [LibraryItem]) {
        var mediaOut: [MediaRecord] = []
        var booksOut: [BookRecord] = []
        var mediaId = 1
        var bookId = 1

        for item in items.sorted(by: { $0.createdAt < $1.createdAt }) {
            switch item.kind {
            case .serie, .peli:
                let omdb = OMDbRecord(rating: item.ratingText, genre: item.genre,
                                      plot: item.plot, imdbId: item.imdbId)
                mediaOut.append(
                    MediaRecord(
                        id: mediaId,
                        uid: item.uid.uuidString,
                        title: item.title,
                        year: item.year,
                        type: item.kind.rawValue,
                        status: item.status.backupValue(for: item.kind),
                        season: item.season,
                        completedAt: item.completedLabel,
                        createdAt: Formatters.iso.string(from: item.createdAt),
                        omdb: omdb.isEmpty ? nil : omdb
                    )
                )
                mediaId += 1
            case .llibre:
                let gbooks = GBooksRecord(publisher: item.publisher, publishedDate: nil,
                                          description: item.plot, infoLink: item.infoLink)
                booksOut.append(
                    BookRecord(
                        id: bookId,
                        uid: item.uid.uuidString,
                        title: item.title,
                        author: item.author,
                        year: item.year,
                        status: item.status.backupValue(for: .llibre),
                        completedAt: item.completedLabel,
                        createdAt: Formatters.iso.string(from: item.createdAt),
                        gbooks: gbooks.isEmpty ? nil : gbooks
                    )
                )
                bookId += 1
            }
        }

        self.init(
            media: mediaOut,
            books: booksOut,
            exportedAt: Formatters.iso.string(from: Date())
        )
    }
}
