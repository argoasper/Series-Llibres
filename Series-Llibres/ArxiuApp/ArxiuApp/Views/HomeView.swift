import SwiftUI
import SwiftData

/// Pantalla d'entrada: els botons de secció grans i, a sota, què tens començat.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history
    @Query private var items: [LibraryItem]

    @State private var route: [LibrarySection] = []
    @State private var showingNew = false

    private var actions: LibraryActions {
        LibraryActions(context: context, history: history)
    }

    private var inProgress: [LibraryItem] {
        items.filter { $0.status == .enCurs }
             .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 12)]
    }

    var body: some View {
        NavigationStack(path: $route) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    grid
                    if !inProgress.isEmpty { continuing }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
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

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            tile(for: .all)
            tile(for: .kind(.serie))
            tile(for: .kind(.peli))
            tile(for: .kind(.llibre))
            tile(for: .status(.enCurs))
            tile(for: .status(.pendent))
        }
        .padding(.top, 4)
    }

    private func tile(for section: LibrarySection) -> some View {
        TileButton(
            symbol: section.symbol,
            label: section.title,
            count: items.filter(section.matches).count,
            color: section.color
        ) {
            route.append(section)
        }
    }

    private var continuing: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Continuant ara")
                .font(.headline)
                .foregroundStyle(Theme.inkDim)

            VStack(spacing: 0) {
                let shown = Array(inProgress.prefix(6))
                ForEach(shown) { item in
                    // El NavigationLink va al darrere i invisible perquè el
                    // cercle d'estat de la fila segueixi sent polsable.
                    ZStack(alignment: .leading) {
                        NavigationLink { ItemDetailView(item: item) } label: { EmptyView() }
                            .opacity(0)
                        ItemRow(item: item, actions: actions)
                    }

                    if item.id != shown.last?.id {
                        Divider().padding(.leading, 85)
                    }
                }
            }
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.panel)
            }
        }
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
