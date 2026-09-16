import SwiftUI
import UIKit

/// Tipografia única de l'app: Helvetica Light a tot arreu.
///
/// `Font.app(_:)` substitueix els estils dinàmics del sistema (`.body`,
/// `.footnote`…) mantenint la mida de cada estil i el Dynamic Type; els pesos
/// (semibold, bold) desapareixen expressament: tota la lletra és Light i
/// l'èmfasi es fa amb la mida i el color.
enum AppFont {
    static let name = "Helvetica-Light"

    static func size(for style: UIFont.TextStyle) -> CGFloat {
        UIFont.preferredFont(forTextStyle: style).pointSize
    }

    static func ui(_ style: UIFont.TextStyle) -> UIFont {
        let points = size(for: style)
        let base = UIFont(name: name, size: points) ?? .systemFont(ofSize: points, weight: .light)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    /// Les parts que SwiftUI delega a UIKit (títols de navegació, botons de
    /// barra, camp de cerca) no hereten el `.font()` de l'entorn: es fixen
    /// aquí, un sol cop, a l'arrencada.
    static func applyAppearance() {
        let nav = UINavigationBar.appearance()
        nav.titleTextAttributes = [.font: ui(.headline)]
        nav.largeTitleTextAttributes = [.font: ui(.largeTitle)]

        let bar = UIBarButtonItem.appearance()
        for state: UIControl.State in [.normal, .highlighted, .disabled] {
            bar.setTitleTextAttributes([.font: ui(.body)], for: state)
        }

        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).font = ui(.body)
        UILabel.appearance(whenContainedInInstancesOf: [UISearchBar.self]).font = ui(.body)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: ui(.footnote)], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: ui(.footnote)], for: .selected)
    }
}

extension Font {
    /// Helvetica Light amb la mida de l'estil dinàmic indicat.
    static func app(_ style: Font.TextStyle = .body) -> Font {
        .custom(AppFont.name, size: AppFont.size(for: style.uiStyle), relativeTo: style)
    }

    /// Helvetica Light amb una mida fixa (escalada segons Dynamic Type).
    static func app(size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(AppFont.name, size: size, relativeTo: style)
    }
}

extension Font.TextStyle {
    var uiStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle:  return .largeTitle
        case .title:       return .title1
        case .title2:      return .title2
        case .title3:      return .title3
        case .headline:    return .headline
        case .subheadline: return .subheadline
        case .body:        return .body
        case .callout:     return .callout
        case .footnote:    return .footnote
        case .caption:     return .caption1
        case .caption2:    return .caption2
        @unknown default:  return .body
        }
    }
}
