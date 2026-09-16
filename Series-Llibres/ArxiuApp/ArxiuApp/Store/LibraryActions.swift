import Foundation
import SwiftData

/// Operacions sobre les fitxes. Concentra en un sol lloc la regla de
/// "marcar com a fet omple el mes automàticament" i el registre per desfer.
@MainActor
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

    /// Elimina la fitxa deixant-ne una còpia a l'històric, perquè "Desfés" la pugui recuperar.
    func delete(_ item: LibraryItem) {
        history.recordDeletion(of: item)
        context.delete(item)
        try? context.save()
        Haptics.warning()
    }

    func insert(_ item: LibraryItem) {
        context.insert(item)
        try? context.save()
    }

    /// Desfà l'últim canvi. Si no hi havia res a desfer (o l'última entrada
    /// apuntava a una fitxa que ja no existeix) fa un retorn hàptic d'avís,
    /// no pas d'èxit.
    func undo() {
        if history.undo(in: context) != nil {
            Haptics.success()
        } else {
            Haptics.warning()
        }
    }
}
