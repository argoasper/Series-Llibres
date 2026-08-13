import UIKit

/// Retorn hàptic lleuger, centralitzat perquè les vistes no toquin UIKit directament.
enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()

    static func tap() {
        selection.selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
