import Foundation
import SwiftData

/// Operacions sobre les fitxes. Concentra en un sol lloc la regla de
/// "marcar com a fet omple el mes automàticament" i el registre per desfer.
struct LibraryActions {
    let context: ModelContext
    let history: ChangeHistory

    /// Passa l'element a l'estat següent (pendent → en curs → fet → pendent).
    func advance(_ item: LibraryItem) {
        set(item, to: item.status.next)
    }

    func set(_ item: LibraryItem, to newStatus: ItemStatus) {
        guard item.status != newStatus else { return }
        let previous = item.status
        let previousDate = item.completedAt

        item.apply(status: newStatus)
        try? context.save()

        history.record(item, from: previous, previousCompletedAt: previousDate)
        Haptics.tap()
    }

    func delete(_ item: LibraryItem) {
        context.delete(item)
        try? context.save()
        Haptics.warning()
    }

    func insert(_ item: LibraryItem) {
        context.insert(item)
        try? context.save()
    }

    func undo() {
        if history.undo(in: context) != nil {
            Haptics.success()
        }
    }
}
