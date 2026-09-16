import Foundation
import SwiftData
import Observation

/// Pila de canvis que es poden desfer: canvis d'estat i eliminacions.
///
/// Les eliminacions hi entren amb una còpia completa de la fitxa, de manera que
/// "Desfés" les pot tornar a inserir tal com estaven.
/// Tot l'estat de l'històric viu al fil principal: el llegeixen i el
/// modifiquen les vistes, i la barra «Desfés» s'amaga sola des d'una Task.
@MainActor
@Observable
final class ChangeHistory {

    /// Còpia completa d'una fitxa, per poder-la reconstruir després d'eliminar-la.
    struct Snapshot {
        var uid: UUID
        var title: String
        var author: String?
        var year: Int?
        var season: Int?
        var kind: MediaKind
        var status: ItemStatus
        var completedAt: Date?
        var createdAt: Date
        var ratingText: String?
        var genre: String?
        var plot: String?
        var imdbId: String?
        var publisher: String?
        var infoLink: String?

        init(_ item: LibraryItem) {
            uid = item.uid
            title = item.title
            author = item.author
            year = item.year
            season = item.season
            kind = item.kind
            status = item.status
            completedAt = item.completedAt
            createdAt = item.createdAt
            ratingText = item.ratingText
            genre = item.genre
            plot = item.plot
            imdbId = item.imdbId
            publisher = item.publisher
            infoLink = item.infoLink
        }

        func makeItem() -> LibraryItem {
            let item = LibraryItem(
                uid: uid, title: title, kind: kind, status: status,
                author: author, year: year, season: season,
                completedAt: completedAt, createdAt: createdAt
            )
            item.ratingText = ratingText
            item.genre = genre
            item.plot = plot
            item.imdbId = imdbId
            item.publisher = publisher
            item.infoLink = infoLink
            item.updatedAt = Date()
            return item
        }
    }

    enum Change {
        case status(previous: ItemStatus, previousCompletedAt: Date?, new: ItemStatus)
        case deletion(Snapshot)
    }

    struct Entry: Identifiable {
        let id = UUID()
        let itemID: UUID
        let title: String
        let kind: MediaKind
        let change: Change
        let date: Date

        var message: String {
            switch change {
            case .status(_, _, let new): return "\(title) → \(new.label(for: kind))"
            case .deletion:              return "\(title) — eliminada"
            }
        }

        var symbol: String {
            switch change {
            case .status(_, _, let new): return new.symbol
            case .deletion:              return "trash"
            }
        }

        var isDeletion: Bool {
            if case .deletion = change { return true }
            return false
        }

        /// Compatibilitat amb el codi que llegia `newStatus` directament.
        var newStatus: ItemStatus? {
            if case .status(_, _, let new) = change { return new }
            return nil
        }
    }

    private(set) var entries: [Entry] = []

    /// Última entrada, mostrada a la barra flotant durant uns segons.
    private(set) var pending: Entry?

    var canUndo: Bool { !entries.isEmpty }

    private var dismissTask: Task<Void, Never>?
    private let limit = 40

    // MARK: - Registre

    func record(_ item: LibraryItem, from previous: ItemStatus, previousCompletedAt: Date?) {
        append(
            Entry(itemID: item.uid, title: item.title, kind: item.kind,
                  change: .status(previous: previous,
                                  previousCompletedAt: previousCompletedAt,
                                  new: item.status),
                  date: Date())
        )
    }

    /// Cal cridar-la ABANS d'esborrar la fitxa del context.
    func recordDeletion(of item: LibraryItem) {
        append(
            Entry(itemID: item.uid, title: item.title, kind: item.kind,
                  change: .deletion(Snapshot(item)), date: Date())
        )
    }

    private func append(_ entry: Entry) {
        entries.append(entry)
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
        show(entry)
    }

    // MARK: - Desfer

    /// Retorna l'entrada desfeta, o `nil` si no s'ha pogut desfer res.
    ///
    /// Si una entrada de canvi d'estat apunta a una fitxa que ja no existeix
    /// (perquè s'ha eliminat o s'ha importat una còpia), es descarta en silenci
    /// i es prova amb l'anterior: així "Desfés" no diu mai que ha fet una cosa
    /// que en realitat no ha fet.
    @discardableResult
    func undo(in context: ModelContext) -> Entry? {
        while let entry = entries.last {
            switch entry.change {
            case .status(let previous, let previousCompletedAt, _):
                let target = entry.itemID
                let descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.uid == target })
                guard let item = try? context.fetch(descriptor).first else {
                    entries.removeLast()          // entrada morta: la descartem i seguim
                    continue
                }
                item.status = previous
                item.completedAt = previousCompletedAt
                item.updatedAt = Date()

            case .deletion(let snapshot):
                context.insert(snapshot.makeItem())
            }

            entries.removeLast()
            try? context.save()
            clearPending()
            return entry
        }

        clearPending()
        return nil
    }

    // MARK: - Barra flotant

    private func show(_ entry: Entry) {
        pending = entry
        dismissTask?.cancel()
        // La tasca s'executa al MainActor (com tota la classe): així `self`
        // es toca sempre des del mateix actor i Swift 6 no es queixa de
        // captures concurrents.
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.pending = nil
        }
    }

    func clearPending() {
        dismissTask?.cancel()
        pending = nil
    }

    /// Buida la pila sencera. Es fa servir després d'importar una còpia:
    /// les entrades antigues apunten a fitxes que ja no existeixen.
    func reset() {
        entries.removeAll()
        clearPending()
    }
}
