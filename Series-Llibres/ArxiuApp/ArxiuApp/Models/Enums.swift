import SwiftUI

/// Els tres tipus de fitxa de l'arxiu. Els `rawValue` són idèntics als de l'HTML
/// original ("serie" / "peli") perquè els backups JSON existents s'importin sense conversions.
enum MediaKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case serie
    case peli
    case llibre

    var id: String { rawValue }

    /// Nom en plural, per als tiles i els filtres.
    var plural: String {
        switch self {
        case .serie:  return "Sèries"
        case .peli:   return "Pel·lícules"
        case .llibre: return "Llibres"
        }
    }

    /// Nom en singular, per als títols de formulari i detall.
    var singular: String {
        switch self {
        case .serie:  return "Sèrie"
        case .peli:   return "Pel·lícula"
        case .llibre: return "Llibre"
        }
    }

    /// Etiqueta curta de la fila de la llista.
    var shortLabel: String {
        switch self {
        case .serie:  return "Sèrie"
        case .peli:   return "Pel·li"
        case .llibre: return "Llibre"
        }
    }

    var symbol: String {
        switch self {
        case .serie:  return "tv"
        case .peli:   return "film"
        case .llibre: return "book.closed"
        }
    }

    /// Colors presos de la icona de l'app: film blau, llibre lila, play vermell.
    var tint: Color {
        switch self {
        case .serie:  return Theme.serieTint
        case .peli:   return Theme.peliTint
        case .llibre: return Theme.llibreTint
        }
    }

    /// Els llibres tenen autor; les sèries, temporada.
    var hasAuthor: Bool { self == .llibre }
    var hasSeason: Bool { self == .serie }
}

/// Estat unificat. A l'HTML hi havia dos vocabularis separats
/// (veient/vist per media, pendent/llegit per llibres); aquí es normalitzen.
enum ItemStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case pendent
    case enCurs
    case fet

    var id: String { rawValue }

    func label(for kind: MediaKind) -> String {
        switch (self, kind) {
        case (.pendent, _):       return "Pendent"
        case (.enCurs, .llibre):  return "Llegint"
        case (.enCurs, _):        return "Veient"
        case (.fet, .llibre):     return "Llegit"
        case (.fet, _):           return "Vist"
        }
    }

    /// Etiqueta neutra per als filtres, on es barregen tipus.
    var neutralLabel: String {
        switch self {
        case .pendent: return "Pendent"
        case .enCurs:  return "En curs"
        case .fet:     return "Fet"
        }
    }

    var symbol: String {
        switch self {
        case .pendent: return "circle"
        case .enCurs:  return "circle.lefthalf.filled"
        case .fet:     return "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pendent: return Theme.inkFaint
        case .enCurs:  return Theme.inProgress
        case .fet:     return Theme.accent
        }
    }

    /// Estat següent en tocar el cercle de la fila: pendent → en curs → fet → pendent.
    var next: ItemStatus {
        switch self {
        case .pendent: return .enCurs
        case .enCurs:  return .fet
        case .fet:     return .pendent
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case title
    case author
    case yearDesc
    case yearAsc
    case recent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title:    return "Títol A–Z"
        case .author:   return "Autor A–Z"
        case .yearDesc: return "Any ↓"
        case .yearAsc:  return "Any ↑"
        case .recent:   return "Acabats recentment"
        }
    }
}
