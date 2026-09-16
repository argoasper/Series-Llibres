import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Si el magatzem s'ha obert amb iCloud, no se sembra res en local:
    /// les dades arriben (o ja hi són) des del núvol.
    var cloudEnabled: Bool = false

    @State private var showingSplash = true

    private var actions: LibraryActions {
        LibraryActions(context: context, history: history)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content

            if let pending = history.pending {
                UndoBar(
                    entry: pending,
                    undo: { actions.undo() },
                    dismiss: { history.clearPending() }
                )
                .padding(.bottom, 12)
            }

            if showingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.snappy(duration: 0.28), value: history.pending?.id)
        .task {
            SeedLoader.seedIfNeeded(context: context, cloudEnabled: cloudEnabled)
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(.easeOut(duration: 0.45)) {
                showingSplash = false
            }
        }
    }

    /// A iPad (i als iPhone grans en horitzontal, on l'amplada també és
    /// `.regular`) fem servir la disposició de dues columnes; a la resta,
    /// l'`HomeView` original, sense cap canvi, dins d'un sol `NavigationStack`.
    @ViewBuilder
    private var content: some View {
        if horizontalSizeClass == .regular {
            IPadHomeView()
        } else {
            HomeView()
        }
    }
}
