import SwiftUI
import SwiftData

/// Formulari d'alta i edició, equivalent als modals de l'HTML.
struct ItemFormView: View {
    enum Mode {
        case create(kind: MediaKind)
        case edit(LibraryItem)
    }

    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title = ""
    @State private var author = ""
    @State private var yearText = ""
    @State private var seasonText = ""
    @State private var kind: MediaKind = .serie
    @State private var status: ItemStatus = .pendent
    @State private var completedText = ""

    @State private var fetched: MetadataService.Result?
    @State private var fetchMessage: String?
    @State private var fetchFailed = false
    @State private var isFetching = false
    @State private var askingForKey = false
    @State private var keyInput = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Títol", text: $title)
                        .textInputAutocapitalization(.words)

                    Picker("Tipus", selection: $kind) {
                        ForEach(MediaKind.allCases) { option in
                            Label(option.singular, systemImage: option.symbol).tag(option)
                        }
                    }

                    if kind.hasAuthor {
                        TextField("Autor", text: $author)
                            .textInputAutocapitalization(.words)
                    }

                    TextField("Any", text: $yearText)
                        .keyboardType(.numberPad)

                    if kind.hasSeason {
                        TextField("Temporada (p. ex. 3)", text: $seasonText)
                            .keyboardType(.numberPad)
                    }
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(ItemStatus.allCases) { option in
                            TileButton(
                                symbol: option.symbol,
                                label: option.label(for: kind),
                                color: LibrarySection.status(option).color,
                                size: .small,
                                selected: status == option
                            ) {
                                status = option
                                syncCompletedText()
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    if status == .fet {
                        TextField("Acabat el (AAAA/MM)", text: $completedText)
                            .keyboardType(.numbersAndPunctuation)
                            .monospacedDigit()
                    }
                } header: {
                    Text("Estat")
                } footer: {
                    if status == .fet {
                        Text("S'omple sol amb el mes actual en marcar-ho com a fet. El pots canviar.")
                    }
                }

                Section {
                    Button {
                        Task { await lookup() }
                    } label: {
                        HStack {
                            Label {
                                Text("Cerca info (" + (kind == .llibre ? "Google Books" : "IMDb") + ")")
                            } icon: {
                                Image(systemName: "sparkle.magnifyingglass")
                            }
                            Spacer()
                            if isFetching { ProgressView() }
                        }
                    }
                    .disabled(!canSave || isFetching)

                    if let fetchMessage {
                        Text(fetchMessage)
                            .font(.footnote)
                            .foregroundStyle(fetchFailed ? Theme.danger : Theme.accent)
                    }

                    if let fetched {
                        if let rating = fetched.rating {
                            LabeledContent("Valoració", value: "★ \(rating)")
                        }
                        if let genre = fetched.genre {
                            LabeledContent("Gènere", value: genre)
                        }
                        if let publisher = fetched.publisher {
                            LabeledContent("Editorial", value: publisher)
                        }
                        if let plot = fetched.plot {
                            Text(plot).font(.footnote).foregroundStyle(Theme.inkDim)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edita fitxa" : "Nova fitxa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desa") { save() }.disabled(!canSave)
                }
            }
            .alert("Clau d'OMDb", isPresented: $askingForKey) {
                TextField("p. ex. a1b2c3d4", text: $keyInput)
                    .textInputAutocapitalization(.never)
                Button("Desa la clau") {
                    MetadataService.omdbKey = keyInput
                    Task { await lookup() }
                }
                Button("Cancel·la", role: .cancel) { }
            } message: {
                Text("Es demana un sol cop i es desa al dispositiu. És gratuïta a omdbapi.com.")
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - Càrrega i desat

    private func load() {
        switch mode {
        case .create(let defaultKind):
            kind = defaultKind
        case .edit(let item):
            title = item.title
            author = item.author ?? ""
            yearText = item.year.map { String($0) } ?? ""
            seasonText = item.season.map { String($0) } ?? ""
            kind = item.kind
            status = item.status
            completedText = item.completedLabel ?? ""
        }
    }

    /// Manté el camp de data coherent amb l'estat, com fa el toggle de la llista.
    private func syncCompletedText() {
        if status == .fet {
            if completedText.isEmpty {
                completedText = Formatters.yearMonth.string(from: Date())
            }
        } else {
            completedText = ""
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let cleanAuthor = author.trimmingCharacters(in: .whitespaces)
        let year = Int(yearText.trimmingCharacters(in: .whitespaces))
        let season = Int(seasonText.trimmingCharacters(in: .whitespaces))
        let completed: Date? = status == .fet
            ? (Formatters.date(fromYearMonth: completedText) ?? Date())
            : nil

        let target: LibraryItem
        switch mode {
        case .edit(let item):
            target = item
        case .create:
            target = LibraryItem(title: cleanTitle, kind: kind)
            context.insert(target)
        }

        target.title = cleanTitle
        target.kind = kind
        target.author = kind.hasAuthor && !cleanAuthor.isEmpty ? cleanAuthor : nil
        target.year = year
        target.season = kind.hasSeason ? season : nil
        target.status = status
        target.completedAt = completed
        target.updatedAt = Date()

        if let fetched {
            target.ratingText = fetched.rating ?? target.ratingText
            target.genre = fetched.genre ?? target.genre
            target.plot = fetched.plot ?? target.plot
            target.imdbId = fetched.imdbId ?? target.imdbId
            target.publisher = fetched.publisher ?? target.publisher
            target.infoLink = fetched.infoLink ?? target.infoLink
        }

        try? context.save()
        Haptics.success()
        dismiss()
    }

    // MARK: - Metadades

    private func lookup() async {
        isFetching = true
        fetchMessage = nil
        defer { isFetching = false }

        do {
            let result = try await MetadataService.lookup(
                title: title.trimmingCharacters(in: .whitespaces),
                year: Int(yearText),
                author: author.trimmingCharacters(in: .whitespaces),
                kind: kind
            )
            fetched = result
            fetchFailed = false
            fetchMessage = "Trobat ✓ — prem «Desa» per guardar-ho."

            if let year = result.year { yearText = String(year) }
            if let resultKind = result.kind { kind = resultKind }
            if kind.hasAuthor, author.isEmpty, let resultAuthor = result.author {
                author = resultAuthor
            }
        } catch MetadataService.ServiceError.missingKey {
            keyInput = MetadataService.omdbKey ?? ""
            askingForKey = true
        } catch {
            fetchFailed = true
            fetchMessage = error.localizedDescription
        }
    }
}
