import SwiftUI
import SwiftData

/// Llista d'una secció, amb el submenú de tiles petits, cerca i ordenació.
struct ItemListView: View {
    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history
    @Query private var items: [LibraryItem]

    let section: LibrarySection

    @State private var search = ""
    @State private var kindFilter: MediaKind?
    @State private var statusFilter: ItemStatus?
    @State private var sort: SortOrder = .title
    @State private var showingNew = false

    init(section: LibrarySection) {
        self.section = section
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

        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !needle.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(needle)
                    || ($0.author?.lowercased().contains(needle) ?? false)
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
        List {
            Section {
                submenu
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if visible.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(visible) { item in
                    ZStack(alignment: .leading) {
                        NavigationLink { ItemDetailView(item: item) } label: { EmptyView() }
                            .opacity(0)
                        ItemRow(item: item, actions: actions)
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
                            actions.delete(item)
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
        .animation(.snappy(duration: 0.25), value: visible.count)
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
                .font(.headline)
                .foregroundStyle(Theme.inkDim)
            Text("Prova de canviar els filtres o afegeix-ne una de nova.")
                .font(.footnote)
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
