import Foundation
import SwiftData
import Observation

/// Pila de canvis d'estat que es poden desfer.
///
/// Només s'hi registren els canvis d'estat (el botó de la fila, els swipes i el
/// selector del formulari): és exactament el que es demanava del botó "Desfés".
@Observable
final class ChangeHistory {

    struct Entry: Identifiable {
        let id = UUID()
        let itemID: UUID
        let title: String
        let previousStatus: ItemStatus
        let previousCompletedAt: Date?
        let newStatus: ItemStatus
        let kind: MediaKind
        let date: Date

        var message: String {
            "\(title) → \(newStatus.label(for: kind))"
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
        let entry = Entry(
            itemID: item.uid,
            title: item.title,
            previousStatus: previous,
            previousCompletedAt: previousCompletedAt,
            newStatus: item.status,
            kind: item.kind,
            date: Date()
        )
        entries.append(entry)
        if entries.count > limit { entries.removeFirst(entries.count - limit) }
        show(entry)
    }

    // MARK: - Desfer

    /// Retorna l'entrada desfeta perquè qui truqui pugui donar retorn a l'usuari.
    @discardableResult
    func undo(in context: ModelContext) -> Entry? {
        guard let entry = entries.popLast() else { return nil }

        let target = entry.itemID
        let descriptor = FetchDescriptor<LibraryItem>(predicate: #Predicate { $0.uid == target })
        if let item = try? context.fetch(descriptor).first {
            item.status = entry.previousStatus
            item.completedAt = entry.previousCompletedAt
            item.updatedAt = Date()
            try? context.save()
        }

        clearPending()
        return entry
    }

    // MARK: - Barra flotant

    private func show(_ entry: Entry) {
        pending = entry
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.pending = nil }
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
