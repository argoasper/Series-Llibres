import Foundation

/// Format exacte del backup que exporta l'HTML: { "media": [...], "books": [...] }.
/// Serveix tant per llegir el fitxer llavor com per importar i exportar des de l'app.
struct Backup: Codable {
    var media: [MediaRecord] = []
    var books: [BookRecord] = []
    var exportedAt: String?

    struct MediaRecord: Codable {
        var id: Int?
        var title: String
        var year: Int?
        var type: String?          // "serie" | "peli"
        var status: String?        // "veient" | "vist"
        var season: Int?           // afegit per l'app
        var completedAt: String?   // "YYYY/MM", afegit per l'app
        var omdb: OMDbRecord?
    }

    struct BookRecord: Codable {
        var id: Int?
        var title: String
        var author: String?
        var year: Int?
        var status: String?        // "llegit" | "pendent"
        var completedAt: String?
        var gbooks: GBooksRecord?
    }

    struct OMDbRecord: Codable {
        var rating: String?
        var genre: String?
        var plot: String?
        var imdbId: String?
    }

    struct GBooksRecord: Codable {
        var publisher: String?
        var publishedDate: String?
        var description: String?
        var infoLink: String?
    }
}

// MARK: - JSON de l'HTML → LibraryItem

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
            let status: ItemStatus = {
                switch record.status {
                case "vist":   return .fet
                case "veient": return .enCurs
                default:       return .pendent
                }
            }()
            let item = LibraryItem(
                title: record.title,
                kind: kind,
                status: status,
                year: record.year,
                season: record.season ?? (kind == .serie ? Backup.season(inTitle: record.title) : nil),
                completedAt: record.completedAt.flatMap(Formatters.date(fromYearMonth:))
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
            let status: ItemStatus = {
                switch record.status {
                case "pendent": return .pendent
                case "llegint": return .enCurs
                default:        return .fet     // l'HTML per defecte tractava els llibres com a llegits
                }
            }()
            let item = LibraryItem(
                title: record.title,
                kind: .llibre,
                status: status,
                author: record.author,
                year: record.year,
                completedAt: record.completedAt.flatMap(Formatters.date(fromYearMonth:))
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

// MARK: - LibraryItem → JSON (exportació compatible amb l'HTML)

extension Backup {
    init(items: [LibraryItem]) {
        var mediaOut: [MediaRecord] = []
        var booksOut: [BookRecord] = []
        var mediaId = 1
        var bookId = 1

        for item in items.sorted(by: { $0.createdAt < $1.createdAt }) {
            switch item.kind {
            case .serie, .peli:
                mediaOut.append(
                    MediaRecord(
                        id: mediaId,
                        title: item.title,
                        year: item.year,
                        type: item.kind.rawValue,
                        status: item.status == .fet ? "vist" : "veient",
                        season: item.season,
                        completedAt: item.completedLabel,
                        omdb: (item.ratingText ?? item.plot ?? item.imdbId) == nil
                            ? nil
                            : OMDbRecord(rating: item.ratingText, genre: item.genre,
                                         plot: item.plot, imdbId: item.imdbId)
                    )
                )
                mediaId += 1
            case .llibre:
                booksOut.append(
                    BookRecord(
                        id: bookId,
                        title: item.title,
                        author: item.author,
                        year: item.year,
                        status: item.status == .fet ? "llegit" : "pendent",
                        completedAt: item.completedLabel,
                        gbooks: (item.publisher ?? item.plot ?? item.infoLink) == nil
                            ? nil
                            : GBooksRecord(publisher: item.publisher, publishedDate: nil,
                                           description: item.plot, infoLink: item.infoLink)
                    )
                )
                bookId += 1
            }
        }

        self.init(
            media: mediaOut,
            books: booksOut,
            exportedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
