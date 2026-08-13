import SwiftUI

/// Barra flotant que apareix uns segons després de canviar un estat.
/// El botó de desfer també és permanent a la barra d'eines de la llista.
struct UndoBar: View {
    let entry: ChangeHistory.Entry
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.newStatus.symbol)
                .foregroundStyle(entry.newStatus == .fet ? Theme.accent : Theme.inProgress)

            Text(entry.message)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Button("Desfés", action: undo)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Capsule().fill(Color(hex: 0x22231F).opacity(0.95))
        }
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
