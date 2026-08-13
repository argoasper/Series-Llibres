import Foundation

/// Cerca de metadades: OMDb per a sèries i pel·lícules, Google Books per a llibres.
/// És el mateix comportament dels botons "Cerca info" de l'HTML.
enum MetadataService {

    struct Result {
        var title: String?
        var year: Int?
        var kind: MediaKind?
        var author: String?
        var rating: String?
        var genre: String?
        var plot: String?
        var imdbId: String?
        var publisher: String?
        var infoLink: String?
    }

    enum ServiceError: LocalizedError {
        case missingKey
        case notFound(String)
        case network(String)

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "Cal una clau d'OMDb per cercar informació de sèries i pel·lícules."
            case .notFound(let detail):
                return detail.isEmpty ? "No s'ha trobat cap resultat." : "No s'ha trobat: \(detail)"
            case .network(let detail):
                return "Error de connexió: \(detail)"
            }
        }
    }

    // MARK: - Clau d'OMDb
    //
    // L'HTML la desava a localStorage des de la pantalla d'Ajustos. Aquella pantalla
    // s'ha eliminat: ara la clau es demana només quan realment fa falta, la primera
    // vegada que es prem "Cerca info" en una sèrie o pel·lícula.

    private static let keyDefaults = "arxiu_omdb_key"

    static var omdbKey: String? {
        get {
            let value = UserDefaults.standard.string(forKey: keyDefaults)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty ?? true) ? nil : value
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                UserDefaults.standard.set(trimmed, forKey: keyDefaults)
            } else {
                UserDefaults.standard.removeObject(forKey: keyDefaults)
            }
        }
    }

    // MARK: - Cerca

    static func lookup(title: String, year: Int?, author: String?, kind: MediaKind) async throws -> Result {
        switch kind {
        case .serie, .peli: return try await lookupOMDb(title: title, year: year)
        case .llibre:       return try await lookupGoogleBooks(title: title, author: author)
        }
    }

    private static func lookupOMDb(title: String, year: Int?) async throws -> Result {
        guard let key = omdbKey else { throw ServiceError.missingKey }

        func request(withYear: Bool) -> URL? {
            var components = URLComponents(string: "https://www.omdbapi.com/")
            var items = [URLQueryItem(name: "apikey", value: key),
                         URLQueryItem(name: "t", value: title)]
            if withYear, let year { items.append(URLQueryItem(name: "y", value: String(year))) }
            components?.queryItems = items
            return components?.url
        }

        var payload = try await fetchJSON(request(withYear: year != nil))
        if (payload["Response"] as? String) == "False", year != nil {
            payload = try await fetchJSON(request(withYear: false))
        }
        guard (payload["Response"] as? String) != "False" else {
            throw ServiceError.notFound(payload["Error"] as? String ?? "")
        }

        func clean(_ key: String) -> String? {
            guard let value = payload[key] as? String, value != "N/A", !value.isEmpty else { return nil }
            return value
        }

        var result = Result()
        result.title = clean("Title")
        result.rating = clean("imdbRating")
        result.genre = clean("Genre")
        result.plot = clean("Plot")
        result.imdbId = clean("imdbID")
        if let yearText = clean("Year") { result.year = Int(yearText.prefix(4)) }
        switch payload["Type"] as? String {
        case "series": result.kind = .serie
        case "movie":  result.kind = .peli
        default:       break
        }
        return result
    }

    private static func lookupGoogleBooks(title: String, author: String?) async throws -> Result {
        var query = "intitle:\(title)"
        if let author, !author.isEmpty { query += "+inauthor:\(author)" }

        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "1")
        ]

        let payload = try await fetchJSON(components?.url)
        guard let items = payload["items"] as? [[String: Any]],
              let info = items.first?["volumeInfo"] as? [String: Any] else {
            throw ServiceError.notFound("")
        }

        var result = Result()
        result.title = info["title"] as? String
        result.publisher = info["publisher"] as? String
        result.plot = info["description"] as? String
        result.infoLink = info["infoLink"] as? String
        if let authors = info["authors"] as? [String], !authors.isEmpty {
            result.author = authors.joined(separator: ", ")
        }
        if let published = info["publishedDate"] as? String {
            result.year = Int(published.prefix(4))
        }
        return result
    }

    private static func fetchJSON(_ url: URL?) async throws -> [String: Any] {
        guard let url else { throw ServiceError.network("URL no vàlida") }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error.localizedDescription)
        }
    }
}
