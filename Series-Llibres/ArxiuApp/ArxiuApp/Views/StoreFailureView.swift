import SwiftUI

/// Pantalla que surt quan SwiftData no ha pogut obrir el magatzem.
/// Abans això era un `fatalError`: l'app petava a l'arrencada sense dir res.
struct StoreFailureView: View {
    let error: Error

    @State private var movedTo: URL?
    @State private var moveError: String?

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.app(size: 48, relativeTo: .largeTitle))
                .foregroundStyle(Theme.danger)

            VStack(spacing: 8) {
                Text("No s'ha pogut obrir l'arxiu")
                    .font(.app(.title3))
                    .foregroundStyle(Theme.ink)

                Text(error.localizedDescription)
                    .font(.app(.footnote))
                    .foregroundStyle(Theme.inkDim)
                    .multilineTextAlignment(.center)
            }

            if let movedTo {
                VStack(spacing: 6) {
                    Text("Magatzem apartat correctament")
                        .font(.app(.subheadline))
                        .foregroundStyle(Theme.accent)
                    Text("Tanca l'app del tot i torna-la a obrir: començarà de zero. "
                         + "El magatzem antic NO s'ha esborrat, és a \(movedTo.lastPathComponent).")
                        .font(.app(.footnote))
                        .foregroundStyle(Theme.inkDim)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 10) {
                    Button {
                        resetStore()
                    } label: {
                        Text("Aparta el magatzem i comença de zero")
                            .font(.app(.subheadline))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.accent)
                            }
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text("No esborra res: mou els fitxers del magatzem a part perquè l'app "
                         + "pugui arrencar. Després pots importar la teva última còpia des del menú «···».")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                }

                if let moveError {
                    Text(moveError)
                        .font(.app(.footnote))
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    /// Mou (mai esborra) els fitxers del magatzem per defecte a una carpeta a part.
    private func resetStore() {
        let fm = FileManager.default
        do {
            let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
            let stamp = Formatters.fileStamp.string(from: Date())
            let quarantine = support.appendingPathComponent("Magatzem-apartat-\(stamp)", isDirectory: true)
            try fm.createDirectory(at: quarantine, withIntermediateDirectories: true)

            var moved = false
            for name in ["default.store", "default.store-shm", "default.store-wal"] {
                let source = support.appendingPathComponent(name)
                guard fm.fileExists(atPath: source.path) else { continue }
                try fm.moveItem(at: source, to: quarantine.appendingPathComponent(name))
                moved = true
            }

            if moved {
                movedTo = quarantine
            } else {
                moveError = "No s'ha trobat cap fitxer de magatzem per apartar. "
                    + "Prova de reinstal·lar l'app després d'haver-ne exportat una còpia."
            }
        } catch {
            moveError = "No s'ha pogut apartar el magatzem: \(error.localizedDescription)"
        }
    }
}

#Preview {
    StoreFailureView(error: NSError(domain: "SwiftData", code: 134110,
                                    userInfo: [NSLocalizedDescriptionKey:
                                        "The model configuration used to open the store is incompatible."]))
}
