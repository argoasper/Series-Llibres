import SwiftUI

/// Fila de la llista: cercle d'estat, títol, temporada, tipus, valoració, any.
struct ItemRow: View {
    let item: LibraryItem
    let actions: LibraryActions

    var body: some View {
        HStack(spacing: 12) {
            statusCircle
            kindIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)

                    if let badge = item.seasonBadge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.serieTint)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Theme.serieTint.opacity(0.14))
                            }
                    }
                }

                if let subtitle = item.subtitleLine {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            if let rating = item.ratingText {
                Text("★ \(rating)")
                    .font(.caption)
                    .foregroundStyle(Theme.inProgress)
            }

            Text(item.year.map { String($0) } ?? "—")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.inkFaint)
                .frame(width: 38, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    /// Distintiu del tipus: tv per a sèries, film per a pel·lícules, llibre per a llibres.
    private var kindIcon: some View {
        Image(systemName: item.kind.symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(item.kind.tint)
            .frame(width: 26, height: 24)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(item.kind.tint.opacity(0.13))
            }
            .accessibilityLabel(item.kind.singular)
    }

    /// Toca per avançar d'estat, com el cercle de l'HTML.
    private var statusCircle: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                actions.advance(item)
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(item.status.tint, lineWidth: 1.6)
                    .frame(width: 21, height: 21)

                switch item.status {
                case .pendent:
                    EmptyView()
                case .enCurs:
                    Circle()
                        .trim(from: 0, to: 0.5)
                        .fill(item.status.tint)
                        .frame(width: 21, height: 21)
                        .rotationEffect(.degrees(-90))
                case .fet:
                    Circle().fill(Theme.accent).frame(width: 21, height: 21)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Estat: \(item.statusLabel). Toca per canviar-lo.")
    }
}
