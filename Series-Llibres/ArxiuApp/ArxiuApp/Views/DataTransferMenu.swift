import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Afegeix a la barra d'eines el menú "···" amb Exporta / Importa
/// i tots els diàlegs que hi van associats.
///
/// S'aplica amb `.dataTransferMenu(items:)` sobre el contingut d'una pantalla
/// que ja sigui dins d'un `NavigationStack`: els `toolbar` es fusionen.
struct DataTransferMenu: ViewModifier {
    let items: [LibraryItem]

    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history

    @State private var document: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false

    /// Còpia ja llegida del disc, esperant confirmació abans de substituir res.
    @State private var staged: Backup?
    @State private var isConfirmingImport = false

    @State private var notice: Notice?
    @State private var showingNotice = false

    private struct Notice {
        let title: String
        let message: String
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    menu
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: document,
                contentType: .json,
                defaultFilename: BackupTransfer.suggestedFilename
            ) { result in
                document = nil
                if case .failure(let error) = result {
                    present(title: "No s'ha pogut exportar", message: error.localizedDescription)
                } else {
                    Haptics.success()
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false,
                onCompletion: handleImportSelection
            )
            .confirmationDialog(
                "Substituir tot l'arxiu?",
                isPresented: $isConfirmingImport,
                titleVisibility: .visible
            ) {
                Button("Substitueix-ho tot", role: .destructive) { commitImport() }
                Button("Cancel·la", role: .cancel) { staged = nil }
            } message: {
                Text(confirmationMessage)
            }
            .alert(notice?.title ?? "", isPresented: $showingNotice) {
                Button("D'acord", role: .cancel) { }
            } message: {
                Text(notice?.message ?? "")
            }
    }

    // MARK: - Menú

    private var menu: some View {
        Menu {
            Button {
                startExport()
            } label: {
                Label("Exporta una còpia…", systemImage: "square.and.arrow.up")
            }
            .disabled(items.isEmpty)

            Button {
                isImporting = true
            } label: {
                Label("Importa una còpia…", systemImage: "square.and.arrow.down")
            }

            Section {
                Text("\(items.count) fitxes a l'arxiu")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Importar i exportar dades")
    }

    // MARK: - Exportar

    private func startExport() {
        do {
            document = try BackupDocument(items: items)
            isExporting = true
        } catch {
            present(title: "No s'ha pogut preparar la còpia",
                    message: error.localizedDescription)
        }
    }

    // MARK: - Importar

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let backup = try BackupTransfer.read(from: url)
                guard !backup.media.isEmpty || !backup.books.isEmpty else {
                    present(title: "Fitxer buit",
                            message: "El JSON no conté cap fitxa ni a «media» ni a «books».")
                    return
                }
                staged = backup
                // Petit marge perquè el selector de fitxers acabi de tancar-se
                // abans de presentar el diàleg de confirmació.
                after(0.35) { isConfirmingImport = true }
            } catch {
                present(title: "Fitxer no vàlid",
                        message: "No s'ha pogut llegir el JSON. Comprova que sigui una còpia de l'arxiu.\n\n\(error.localizedDescription)")
            }
        case .failure(let error):
            present(title: "No s'ha pogut obrir el fitxer",
                    message: error.localizedDescription)
        }
    }

    private var confirmationMessage: String {
        guard let staged else { return "" }
        let entrants = staged.media.count + staged.books.count
        return "El fitxer conté \(staged.media.count) sèries i pel·lícules i \(staged.books.count) llibres (\(entrants) fitxes). Les \(items.count) fitxes actuals s'esborraran."
    }

    private func commitImport() {
        guard let backup = staged else { return }
        staged = nil
        do {
            try SeedLoader.replaceAll(with: backup, context: context)
            history.reset()
            Haptics.success()
            present(title: "Importació feta",
                    message: "S'han carregat \(backup.media.count + backup.books.count) fitxes.")
        } catch {
            Haptics.warning()
            present(title: "No s'ha pogut importar", message: error.localizedDescription)
        }
    }

    // MARK: - Avisos

    private func present(title: String, message: String) {
        notice = Notice(title: title, message: message)
        after(0.35) { showingNotice = true }
    }

    private func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}

extension View {
    func dataTransferMenu(items: [LibraryItem]) -> some View {
        modifier(DataTransferMenu(items: items))
    }
}
