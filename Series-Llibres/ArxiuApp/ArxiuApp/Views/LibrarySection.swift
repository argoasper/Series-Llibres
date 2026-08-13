import SwiftUI

/// Una secció de la pantalla d'entrada. Cada tile n'obre una.
enum LibrarySection: Hashable, Identifiable {
    case all
    case kind(MediaKind)
    case status(ItemStatus)

    var id: String {
        switch self {
        case .all:              return "all"
        case .kind(let k):      return "kind-\(k.rawValue)"
        case .status(let s):    return "status-\(s.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .all:              return "Tot"
        case .kind(let k):      return k.plural
        case .status(let s):    return s.neutralLabel
        }
    }

    var symbol: String {
        switch self {
        case .all:              return "square.grid.2x2.fill"
        case .kind(let k):      return k.symbol
        case .status(let s):    return s.symbol
        }
    }

    var color: Color {
        switch self {
        case .all:              return Theme.allTint
        case .kind(let k):      return k.tint
        case .status(.enCurs):  return Theme.progressTint
        case .status(.pendent): return Color(hex: 0x8A8F98)
        case .status(.fet):     return Theme.accent
        }
    }

    /// Tipus permesos dins la secció.
    var kinds: Set<MediaKind> {
        switch self {
        case .kind(let k): return [k]
        default:           return Set(MediaKind.allCases)
        }
    }

    /// Estat amb què s'obre la llista.
    var initialStatus: ItemStatus? {
        if case .status(let s) = self { return s }
        return nil
    }

    /// Tipus per defecte en crear una fitxa nova des d'aquesta secció.
    var defaultKind: MediaKind {
        if case .kind(let k) = self { return k }
        return .serie
    }

    func matches(_ item: LibraryItem) -> Bool {
        guard kinds.contains(item.kind) else { return false }
        if let initialStatus { return item.status == initialStatus }
        return true
    }
}
