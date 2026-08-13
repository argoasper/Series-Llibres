import SwiftUI

/// Imatge d'entrada. Apareix per sobre de l'app i es retira sola amb un fos.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.bg, Theme.accentSoft],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Image("LaunchArt")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 190)
                    .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
                    .scaleEffect(appeared ? 1 : 0.86)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 6) {
                    Text("El Meu Arxiu")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("Sèries · Pel·lícules · Llibres")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkDim)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            }
        }
        .task {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

#Preview {
    SplashView()
}
