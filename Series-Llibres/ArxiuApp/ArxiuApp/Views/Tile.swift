import SwiftUI

/// El tile de colors de la referència: icona a dalt a l'esquerra, comptador a
/// dalt a la dreta i etiqueta a baix. `size` decideix si és un botó de secció
/// gran (pantalla d'entrada) o un del submenú, més petit.
struct Tile: View {
    enum Size {
        case large
        case small

        var height: CGFloat { self == .large ? Theme.tileHeight : Theme.smallTileHeight }
        var corner: CGFloat { self == .large ? Theme.tileCorner : 13 }
        var padding: CGFloat { self == .large ? 14 : 10 }
        var iconFont: Font { self == .large ? .title3.weight(.semibold) : .caption.weight(.semibold) }
        var countFont: Font { self == .large ? .title2.weight(.bold) : .subheadline.weight(.bold) }
        var labelFont: Font { self == .large ? .subheadline.weight(.semibold) : .caption2.weight(.semibold) }
    }

    let symbol: String
    let label: String
    let count: Int?
    let color: Color
    var size: Size = .large
    var selected: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: symbol)
                    .font(size.iconFont)
                Spacer(minLength: 4)
                if let count {
                    Text("\(count)")
                        .font(size.countFont)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 2)
            Text(label)
                .font(size.labelFont)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(selected ? .white : color)
        .padding(size.padding)
        .frame(maxWidth: .infinity, minHeight: size.height, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .fill(selected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.13)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: size.corner, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0.18 : 0), lineWidth: 1)
        }
        .shadow(color: selected ? color.opacity(0.28) : .clear,
                radius: size == .large ? 8 : 4, y: size == .large ? 4 : 2)
        .contentShape(RoundedRectangle(cornerRadius: size.corner, style: .continuous))
        .animation(.snappy(duration: 0.22), value: selected)
    }
}

/// Versió polsable amb un lleuger enfonsament, com els botons natius de la referència.
struct TileButton: View {
    let symbol: String
    let label: String
    var count: Int? = nil
    let color: Color
    var size: Tile.Size = .large
    var selected: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            Tile(symbol: symbol, label: label, count: count,
                 color: color, size: size, selected: selected)
        }
        .buttonStyle(PressableTileStyle())
    }
}

private struct PressableTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

#Preview("Tiles") {
    ScrollView {
        VStack(spacing: 18) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                Tile(symbol: "square.grid.2x2.fill", label: "Tot", count: 487, color: Theme.allTint)
                Tile(symbol: "tv", label: "Sèries", count: 220, color: Theme.serieTint)
                Tile(symbol: "film", label: "Pel·lícules", count: 135, color: Theme.peliTint)
                Tile(symbol: "book.closed", label: "Llibres", count: 132, color: Theme.llibreTint)
            }
            HStack(spacing: 8) {
                Tile(symbol: "circle", label: "Pendent", count: 3, color: Theme.inkFaint, size: .small, selected: false)
                Tile(symbol: "circle.lefthalf.filled", label: "En curs", count: 5, color: Theme.progressTint, size: .small)
                Tile(symbol: "checkmark.circle.fill", label: "Fet", count: 479, color: Theme.accent, size: .small, selected: false)
            }
        }
        .padding()
    }
}
