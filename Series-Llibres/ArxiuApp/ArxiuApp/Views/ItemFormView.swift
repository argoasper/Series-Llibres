import SwiftUI
import SwiftData

/// Formulari d'alta i edició, equivalent als modals de l'HTML.
struct ItemFormView: View {
    enum Mode {
        case create(kind: MediaKind)
        case edit(LibraryItem)
    }

    private enum Field: Hashable {
        case title, author, year, season, completed
    }

    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title: String
    @State private var author: String
    @State private var yearText: String
    @State private var seasonText: String
    @State private var kind: MediaKind
    @State private var status: ItemStatus
    @State private var completedText: String

    @State private var fetched: MetadataService.Result?
    @State private var fetchMessage: String?
    @State private var fetchFailed = false
    @State private var isFetching = false
    @State private var askingForKey = false
    @State private var keyInput = ""

    @FocusState private var focus: Field?

    /// Els valors inicials es fixen aquí, no a `.onAppear`.
    /// `onAppear` es torna a disparar cada cop que la vista reapareix (en tancar
    /// l'alerta de la clau, en tornar de segon pla…) i esborrava el que l'usuari
    /// estigués escrivint.
    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create(let defaultKind):
            _title = State(initialValue: "")
            _author = State(initialValue: "")
            _yearText = State(initialValue: "")
            _seasonText = State(initialValue: "")
            _kind = State(initialValue: defaultKind)
            _status = State(initialValue: .pendent)
            _completedText = State(initialValue: "")
        case .edit(let item):
            _title = State(initialValue: item.title)
            _author = State(initialValue: item.author ?? "")
            _yearText = State(initialValue: item.year.map { String($0) } ?? "")
            _seasonText = State(initialValue: item.season.map { String($0) } ?? "")
            _kind = State(initialValue: item.kind)
            _status = State(initialValue: item.status)
            _completedText = State(initialValue: item.completedLabel ?? "")
        }
    }

    private var actions: LibraryActions {
        LibraryActions(context: context, history: history)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    // MARK: - Validació

    private var cleanTitle: String { title.trimmingCharacters(in: .whitespaces) }

    private var completedDate: Date? { Formatters.date(fromYearMonth: completedText) }

    /// Buit vol dir "omple'l tu amb el mes actual"; qualsevol altra cosa ha de
    /// ser una data real. Abans, un text invàlid es desava en silenci com la
    /// data d'AVUI, cosa que corrompia l'històric sense avisar.
    private var completedIsValid: Bool {
        status != .fet
            || completedText.trimmingCharacters(in: .whitespaces).isEmpty
            || completedDate != nil
    }

    private var yearValue: Int? { Int(yearText.trimmingCharacters(in: .whitespaces)) }

    private var yearIsValid: Bool {
        guard !yearText.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        guard let year = yearValue else { return false }
        let limit = Calendar.current.component(.year, from: Date()) + 5
        return year >= 1450 && year <= limit
    }

    private var canSave: Bool { !cleanTitle.isEmpty && completedIsValid && yearIsValid }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Títol", text: $title)
                        .textInputAutocapitalization(.words)
                        .focused($focus, equals: .title)

                    Picker("Tipus", selection: $kind) {
                        ForEach(MediaKind.allCases) { option in
                            Label(option.singular, systemImage: option.symbol).tag(option)
                        }
                    }

                    if kind.hasAuthor {
                        TextField("Autor", text: $author)
                            .textInputAutocapitalization(.words)
                            .focused($focus, equals: .author)
                    }

                    TextField("Any", text: $yearText)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .year)

                    if !yearIsValid {
                        Text("L'any ha de ser un número entre 1450 i \(Calendar.current.component(.year, from: Date()) + 5).")
                            .font(.app(.footnote))
                            .foregroundStyle(Theme.danger)
                    }

                    if kind.hasSeason {
                        TextField("Temporada (p. ex. 3)", text: $seasonText)
                            .keyboardType(.numberPad)
                            .focused($focus, equals: .season)
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
                            .focused($focus, equals: .completed)

                        if !completedIsValid {
                            Text("Escriu-ho com AAAA/MM, per exemple 2026/08. Deixa-ho buit per posar-hi el mes actual.")
                                .font(.app(.footnote))
                                .foregroundStyle(Theme.danger)
                        }
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
                        focus = nil
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
                    .disabled(cleanTitle.isEmpty || isFetching)

                    if let fetchMessage {
                        Text(fetchMessage)
                            .font(.app(.footnote))
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
                            Text(plot).font(.app(.footnote)).foregroundStyle(Theme.inkDim)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edita fitxa" : "Nova fitxa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desa") { save() }.disabled(!canSave)
                }
                // El teclat numèric no té tecla de retorn: sense això, dins d'un
                // Form no hi ha manera fiable de tancar-lo.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fet") { focus = nil }
                        .font(.app(.body))
                }
            }
            // Si es canvia el títol o el tipus després d'una cerca, el resultat
            // anterior deixa de ser vàlid: desar-lo aplicaria la sinopsi, la
            // valoració i l'imdbID d'una altra obra.
            .onChange(of: title) { invalidateLookup() }
            .onChange(of: kind) { invalidateLookup() }
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
        }
    }

    // MARK: - Desat

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

    private func invalidateLookup() {
        guard fetched != nil || fetchMessage != nil else { return }
        fetched = nil
        fetchMessage = nil
        fetchFailed = false
    }

    private func save() {
        guard canSave else { return }

        let cleanAuthor = author.trimmingCharacters(in: .whitespaces)
        let season = Int(seasonText.trimmingCharacters(in: .whitespaces))
        let completed: Date? = status == .fet ? (completedDate ?? Date()) : nil

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
        target.year = yearValue
        target.season = kind.hasSeason ? season : nil

        if isEditing {
            // El canvi d'estat passa per LibraryActions perquè quedi a
            // l'històric i el botó "Desfés" el pugui revertir. Abans s'assignava
            // directament i el formulari era l'únic lloc que se saltava el registre.
            actions.set(target, to: status)
        } else {
            target.status = status
        }
        // La data escrita a mà mana sobre l'automàtica d'`apply(status:)`.
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

        let searchedTitle = cleanTitle

        do {
            let result = try await MetadataService.lookup(
                title: searchedTitle,
                year: yearValue,
                author: author.trimmingCharacters(in: .whitespaces),
                kind: kind
            )
            // Si mentrestant l'usuari ha canviat el títol, el resultat ja no val.
            guard searchedTitle == cleanTitle else { return }

            fetched = result
            fetchFailed = false

            if let year = result.year, yearText.isEmpty { yearText = String(year) }
            if kind.hasAuthor, author.isEmpty, let resultAuthor = result.author {
                author = resultAuthor
            }

            // El tipus NO es canvia sol: només se suggereix.
            if let resultKind = result.kind, resultKind != kind {
                fetchMessage = "Trobat ✓ — segons \(kind == .llibre ? "Google Books" : "OMDb") és una \(resultKind.singular.lowercased()). "
                    + "Canvia-ho tu al selector de Tipus si vols. Prem «Desa» per guardar la resta."
            } else {
                fetchMessage = "Trobat ✓ — prem «Desa» per guardar-ho."
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
