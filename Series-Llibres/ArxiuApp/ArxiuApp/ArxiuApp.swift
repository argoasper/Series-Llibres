import SwiftUI
import SwiftData

@main
struct ArxiuApp: App {
    @State private var history = ChangeHistory()

    /// Contenidor iCloud (CloudKit) de l'app. Ha de coincidir amb el que hi ha
    /// a `ArxiuApp.entitlements` i amb el que Xcode crea a Signing & Capabilities.
    static let cloudContainerID = "iCloud.com.francescgallego.ArxiuApp"

    /// Interruptor d'iCloud. Posa'l a `true` NOMÉS quan el projecte tingui la
    /// capability iCloud (CloudKit) activada a Signing & Capabilities amb un
    /// equip de pagament. Demanar CloudKit sense l'entitlement no llança cap
    /// error recuperable: CloudKit fa petar l'app (`_os_crash`) en un fil
    /// secundari abans que el `try?` pugui fer res.
    static let cloudKitEnabled = false

    /// Si el magatzem no es pot obrir (migració fallida, fitxer malmès…) NO es
    /// fa `fatalError`: l'app arrencava petant, sense missatge i sense sortida.
    /// Aquí es guarda l'error i s'ensenya una pantalla de recuperació.
    private let container: Result<ModelContainer, Error>

    /// `true` si el magatzem s'ha obert amb sincronització iCloud activa.
    private let cloudEnabled: Bool

    init() {
        AppFont.applyAppearance()

        let schema = Schema([LibraryItem.self])

        // Amb l'interruptor activat s'intenta primer amb iCloud; si no es pot
        // (simulador sense compte, error de configuració), es torna a obrir el
        // MATEIX fitxer només en local: l'usuari no perd res.
        let cloud = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(Self.cloudContainerID)
        )
        if Self.cloudKitEnabled,
           let cloudContainer = try? ModelContainer(for: schema, configurations: [cloud]) {
            container = .success(cloudContainer)
            cloudEnabled = true
        } else {
            let local = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            do {
                container = .success(try ModelContainer(for: schema, configurations: [local]))
            } catch {
                container = .failure(error)
            }
            cloudEnabled = false
        }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootView(cloudEnabled: cloudEnabled)
                    .environment(history)
                    .tint(Theme.accent)
                    .font(.app(.body))
                    .modelContainer(container)
            case .failure(let error):
                StoreFailureView(error: error)
                    .tint(Theme.accent)
                    .font(.app(.body))
            }
        }
    }
}
