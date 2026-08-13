import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history
    @Environment(\.dismiss) private var dismiss

    @Bindable var item: LibraryItem

    @State private var editing = false
    @State private var confirmingDelete = false

    private var actions: LibraryActions {
        LibraryActions(context: context, history: history)
    }

    var body: some View {
        List {
            Section {
                header
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section("Estat") {
                statusPicker
                if let completed = item.completedLabel {
                    LabeledContent {
                        Text(completed)
                    } label: {
                        Text(item.kind == .llibre ? "Llegit el" : "Vist el")
                    }
                }
            }

            Section("Dades") {
                LabeledContent("Tipus", value: item.kind.singular)
                if let author = item.author, !author.isEmpty {
                    LabeledContent("Autor", value: author)
                }
                if let year = item.year {
                    LabeledContent("Any", value: String(year))
                }
                if item.kind.hasSeason, let season = item.season {
                    LabeledContent("Temporada", value: "T\(season)")
                }
                if let rating = item.ratingText {
                    LabeledContent("Valoració", value: "★ \(rating)")
                }
                if let genre = item.genre {
                    LabeledContent("Gènere", value: genre)
                }
                if let publisher = item.publisher {
                    LabeledContent("Editorial", value: publisher)
                }
            }

            if let plot = item.plot, !plot.isEmpty {
                Section("Sinopsi") {
                    Text(plot)
                        .font(.callout)
                        .foregroundStyle(Theme.inkDim)
                }
            }

            if let url = item.externalURL {
                Section {
                    Link(destination: url) {
                        Label("Obre a \(item.externalName)", systemImage: "arrow.up.right.square")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Elimina", systemImage: "trash")
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edita") { editing = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                UndoToolbarButton(actions: actions)
            }
        }
        .sheet(isPresented: $editing) {
            ItemFormView(mode: .edit(item))
        }
        .confirmationDialog("Segur que vols eliminar aquesta fitxa?",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                actions.delete(item)
                dismiss()
            }
            Button("Cancel·la", role: .cancel) { }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.kind.tint.gradient)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: item.kind.symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)

                HStack(spacing: 6) {
                    Text(item.kind.singular)
                    if let badge = item.seasonBadge { Text("· \(badge)") }
                    if let year = item.year { Text("· \(String(year))") }
                }
                .font(.footnote)
                .foregroundStyle(Theme.inkDim)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusPicker: some View {
        HStack(spacing: 8) {
            ForEach(ItemStatus.allCases) { status in
                TileButton(
                    symbol: status.symbol,
                    label: status.label(for: item.kind),
                    color: LibrarySection.status(status).color,
                    size: .small,
                    selected: item.status == status
                ) {
                    actions.set(item, to: status)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
