import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(ChangeHistory.self) private var history

    @State private var showingSplash = true

    private var actions: LibraryActions {
        LibraryActions(context: context, history: history)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            HomeView()

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
            SeedLoader.seedIfNeeded(context: context)
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(.easeOut(duration: 0.45)) {
                showingSplash = false
            }
        }
    }
}
