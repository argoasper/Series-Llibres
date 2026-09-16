import SwiftUI
import SwiftData

/// Disposició de dues columnes (sidebar + detall) per a iPad i per als iPhone
/// grans en horitzontal. Fa servir exactament els mateixos tiles i seccions
/// que `HomeView`; l'únic que canvia és com es mostren: en lloc d'apilar-se
/// en un sol `NavigationStack`, seleccionar un tile actualitza la columna de
/// detall (que reutilitza `ItemListView`/`ItemDetailView` sense tocar-los).
struct IPadHomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history
    @Query private var items: [LibraryItem]

    @State private var selection: LibrarySection? = .all
    @State private var showingNew = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var actions: LibraryActions {
        LibraryActions(context: context, history: history)
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            NavigationStack {
                Group {
                    if let selection {
                        // .id(selection) és necessari: sense identitat pròpia per
                        // secció, SwiftUI reutilitza el mateix estat intern de
                        // `ItemListView` (kindFilter/statusFilter) en canviar de
                        // tile, i la llista deixa de "distingir" entre En curs,
                        // Pendent, etc. — es queda amb el filtre de la primera
                        // secció que es va mostrar.
                        ItemListView(section: selection, showsSubmenu: false)
                            .id(selection)
                    } else {
                        ContentUnavailableView(
                            "Selecciona una secció",
                            systemImage: "square.grid.2x2",
                            description: Text("Tria Tot, Sèries, Pel·lícules, Llibres, En curs o Pendent a l'esquerra.")
                        )
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                tile(for: .all)
                tile(for: .kind(.serie))
                tile(for: .kind(.peli))
                tile(for: .kind(.llibre))
                tile(for: .status(.enCurs))
                tile(for: .status(.pendent))
            }
            .padding(16)
        }
        .background(Theme.bg)
        .navigationTitle("Sèries-Pel·lícules-Llibres")
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
        .sheet(isPresented: $showingNew) {
            ItemFormView(mode: .create(kind: selection?.defaultKind ?? .serie))
        }
    }

    private func tile(for section: LibrarySection) -> some View {
        TileButton(
            symbol: section.heroSymbol,
            label: section.title,
            count: items.filter(section.matches).count,
            color: section.color,
            selected: selection == section
        ) {
            selection = section
        }
    }
}

#Preview("iPad") {
    IPadHomeView()
        .environment(ChangeHistory())
        .modelContainer(for: LibraryItem.self, inMemory: true)
}
