import SwiftUI
import SwiftData

/// Llista d'una secció, amb el submenú de tiles petits, cerca i ordenació.
struct ItemListView: View {
    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history
    @Query private var items: [LibraryItem]

    let section: LibrarySection

    /// A iPad, dins la columna de detall, la navegació de secció/estat ja la fa
    /// el sidebar (`IPadHomeView`): amaguem aquest submenú perquè no es dupliqui.
    let showsSubmenu: Bool

    @State private var search = ""
    @State private var kindFilter: MediaKind?
    @State private var statusFilter: ItemStatus?
    @State private var sort: SortOrder = .title
    @State private var showingNew = false
    @State private var pendingDeletion: LibraryItem?
    @State private var editing: LibraryItem?
    @State private var detail: LibraryItem?

    init(section: LibrarySection, showsSubmenu: Bool = true) {
        self.section = section
        self.showsSubmenu = showsSubmenu
        _statusFilter = State(initialValue: section.initialStatus)
    }

    private var actions: LibraryActions {
        LibraryActions(context: context, history: history)
    }

    /// Elements de la secció abans d'aplicar cerca i filtres: la base dels comptadors.
    private var scope: [LibraryItem] {
        items.filter { section.kinds.contains($0.kind) }
    }

    private var visible: [LibraryItem] {
        var list = scope

        if let kindFilter { list = list.filter { $0.kind == kindFilter } }
        if let statusFilter { list = list.filter { $0.status == statusFilter } }

        // `localizedStandardContains` ignora majúscules I accents: buscar
        // "Fundacio" ha de trobar "Fundació" (37 títols de l'arxiu porten accents).
        let needle = search.trimmingCharacters(in: .whitespaces)
        if !needle.isEmpty {
            list = list.filter {
                $0.title.localizedStandardContains(needle)
                    || ($0.author?.localizedStandardContains(needle) ?? false)
            }
        }

        return list.sorted(by: comparator)
    }

    private func comparator(_ a: LibraryItem, _ b: LibraryItem) -> Bool {
        switch sort {
        case .title:
            return a.title.localizedStandardCompare(b.title) == .orderedAscending
        case .author:
            return (a.author ?? "").localizedStandardCompare(b.author ?? "") == .orderedAscending
        case .yearDesc:
            return (a.year ?? 0) > (b.year ?? 0)
        case .yearAsc:
            return (a.year ?? 9999) < (b.year ?? 9999)
        case .recent:
            return (a.completedAt ?? .distantPast) > (b.completedAt ?? .distantPast)
        }
    }

    var body: some View {
        // `visible` filtra i ordena tota la col·lecció: s'avalua UNA vegada per
        // render, no tres (isEmpty + ForEach + animation), que era el que passava.
        let rows = visible

        return List {
            if showsSubmenu {
                Section {
                    submenu
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            if rows.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(rows) { item in
                    // Tocar la fila obre directament el formulari d'edició.
                    // El detall (sinopsi, enllaç a IMDb/Goodreads…) queda a
                    // mantenir premut → «Veure detall».
                    ItemRow(item: item, actions: actions)
                        .onTapGesture { editing = item }
                        .contextMenu {
                            Button { editing = item } label: {
                                Label("Edita", systemImage: "pencil")
                            }
                            Button { detail = item } label: {
                                Label("Veure detall", systemImage: "info.circle")
                            }
                        }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Theme.panel)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            actions.set(item, to: item.status == .fet ? .pendent : .fet)
                        } label: {
                            Label {
                                Text(item.status == .fet ? "Desmarca" : "Fet")
                            } icon: {
                                Image(systemName: item.status == .fet ? "arrow.uturn.backward" : "checkmark")
                            }
                        }
                        .tint(item.status == .fet ? Theme.inProgress : Theme.accent)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeletion = item
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                        Button {
                            actions.set(item, to: .enCurs)
                        } label: {
                            Label("En curs", systemImage: "circle.lefthalf.filled")
                        }
                        .tint(Theme.progressTint)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(section == .kind(.llibre) ? "Cerca per títol o autor…" : "Cerca per títol…"))
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.large)
        .animation(.snappy(duration: 0.25), value: rows.count)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nova fitxa")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Ordena", selection: $sort) {
                        ForEach(sortOptions) { option in
                            Text(option.label).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                UndoToolbarButton(actions: actions)
            }
        }
        .sheet(isPresented: $showingNew) {
            ItemFormView(mode: .create(kind: kindFilter ?? section.defaultKind))
        }
        .sheet(item: $editing) { item in
            ItemFormView(mode: .edit(item))
        }
        .navigationDestination(item: $detail) { item in
            ItemDetailView(item: item)
        }
        .confirmationDialog(
            "Segur que vols eliminar «\(pendingDeletion?.title ?? "")»?",
            isPresented: Binding(get: { pendingDeletion != nil },
                                 set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Elimina", role: .destructive) {
                if let item = pendingDeletion { actions.delete(item) }
                pendingDeletion = nil
            }
            Button("Cancel·la", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("La podràs recuperar amb «Desfés» mentre no tanquis l'app.")
        }
    }

    private var sortOptions: [SortOrder] {
        var options: [SortOrder] = [.title, .yearDesc, .yearAsc, .recent]
        if section.kinds.contains(.llibre) { options.insert(.author, at: 1) }
        return options
    }

    // MARK: - Submenú de tiles petits

    private var submenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            if section.kinds.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        smallTile(symbol: "square.grid.2x2.fill", label: "Tot",
                                  count: scope.count, color: Theme.allTint,
                                  active: kindFilter == nil) { kindFilter = nil }

                        ForEach(MediaKind.allCases.filter(section.kinds.contains)) { kind in
                            smallTile(symbol: kind.symbol, label: kind.plural,
                                      count: scope.filter { $0.kind == kind }.count,
                                      color: kind.tint,
                                      active: kindFilter == kind) {
                                kindFilter = (kindFilter == kind) ? nil : kind
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    smallTile(symbol: "circle.grid.2x2", label: "Tots",
                              count: statusScope.count, color: Theme.inkDim,
                              active: statusFilter == nil) { statusFilter = nil }

                    ForEach(ItemStatus.allCases) { status in
                        smallTile(symbol: status.symbol, label: status.neutralLabel,
                                  count: statusScope.filter { $0.status == status }.count,
                                  color: LibrarySection.status(status).color,
                                  active: statusFilter == status) {
                            statusFilter = (statusFilter == status) ? nil : status
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    /// Els comptadors d'estat respecten el filtre de tipus actiu.
    private var statusScope: [LibraryItem] {
        guard let kindFilter else { return scope }
        return scope.filter { $0.kind == kindFilter }
    }

    private func smallTile(symbol: String, label: String, count: Int,
                           color: Color, active: Bool, action: @escaping () -> Void) -> some View {
        TileButton(symbol: symbol, label: label, count: count, color: color,
                   size: .small, selected: active, action: action)
            .frame(width: 108)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Cap fitxa trobada")
                .font(.app(.headline))
                .foregroundStyle(Theme.inkDim)
            Text("Prova de canviar els filtres o afegeix-ne una de nova.")
                .font(.app(.footnote))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
