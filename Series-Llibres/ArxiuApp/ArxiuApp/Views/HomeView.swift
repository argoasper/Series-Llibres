import SwiftUI
import SwiftData

/// Pantalla d'entrada: els botons de secció grans, repartits per tota la pantalla.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history
    @Query private var items: [LibraryItem]

    @State private var route: [LibrarySection] = []
    @State private var showingNew = false

    private var actions: LibraryActions {
        LibraryActions(context: context, history: history)
    }

    /// Les 6 caselles principals, en l'ordre en què apareixen a la graella.
    private let sections: [LibrarySection] = [
        .all, .kind(.serie), .kind(.peli), .kind(.llibre), .status(.enCurs), .status(.pendent)
    ]

    private let numberOfColumns = 2
    private let spacing: CGFloat = 12
    private let horizontalInset: CGFloat = 16
    private let verticalInset: CGFloat = 12

    var body: some View {
        NavigationStack(path: $route) {
            GeometryReader { geo in
                let rows = Int(ceil(Double(sections.count) / Double(numberOfColumns)))
                let availableHeight = geo.size.height
                    - verticalInset * 2
                    - spacing * CGFloat(rows - 1)
                let tileHeight = max(Theme.tileHeight, availableHeight / CGFloat(rows))

                ScrollView {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: spacing),
                            count: numberOfColumns
                        ),
                        spacing: spacing
                    ) {
                        ForEach(sections) { section in
                            tile(for: section, height: tileHeight)
                        }
                    }
                    .padding(.horizontal, horizontalInset)
                    .padding(.vertical, verticalInset)
                    .frame(minHeight: geo.size.height)
                }
            }
            .background(Theme.bg)
            .navigationTitle("El Meu Arxiu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nova fitxa")
                }
                ToolbarItem(placement: .topBarLeading) {
                    UndoToolbarButton(actions: actions)
                }
            }
            .dataTransferMenu(items: items)
            .navigationDestination(for: LibrarySection.self) { section in
                ItemListView(section: section)
            }
            .sheet(isPresented: $showingNew) {
                ItemFormView(mode: .create(kind: .serie))
            }
        }
    }

    private func tile(for section: LibrarySection, height: CGFloat) -> some View {
        TileButton(
            symbol: section.heroSymbol,
            label: section.title,
            count: items.filter(section.matches).count,
            color: section.color
        ) {
            route.append(section)
        }
        .frame(height: height)
    }
}

/// Botó de desfer reutilitzat a la pantalla d'entrada i a les llistes.
struct UndoToolbarButton: View {
    @Environment(ChangeHistory.self) private var history
    let actions: LibraryActions

    var body: some View {
        Button {
            actions.undo()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .disabled(!history.canUndo)
        .accessibilityLabel("Desfés l'últim canvi d'estat")
    }
}
