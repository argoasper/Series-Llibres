import SwiftUI

/// Barra flotant que apareix uns segons després d'un canvi.
/// El botó de desfer també és permanent a la barra d'eines de la llista.
struct UndoBar: View {
    let entry: ChangeHistory.Entry
    let undo: () -> Void
    let dismiss: () -> Void

    /// La càpsula és sempre fosca, també en mode clar: per això els colors de
    /// dins són fixos i es trien per contrast sobre fosc, no pels de Theme
    /// (l'accent clar #3F6659 sobre #22231F quedava il·legible).
    private static let capsuleInk   = Color(hex: 0x22231F)
    private static let onDarkAccent = Color(hex: 0x8FC7B1)
    private static let onDarkWarn   = Color(hex: 0xE8B87A)
    private static let onDarkDanger = Color(hex: 0xE8918A)

    private var iconTint: Color {
        if entry.isDeletion { return Self.onDarkDanger }
        switch entry.newStatus {
        case .fet:     return Self.onDarkAccent
        case .enCurs:  return Self.onDarkWarn
        default:       return .white.opacity(0.75)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.symbol)
                .foregroundStyle(iconTint)

            Text(entry.message)
                .font(.app(.footnote))
                .lineLimit(2)
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Button("Desfés", action: undo)
                .font(.app(.footnote))
                .buttonStyle(.plain)
                .foregroundStyle(Self.onDarkAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.app(.caption))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tanca l'avís")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .background {
            Capsule().fill(Self.capsuleInk.opacity(0.96))
        }
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }
}
