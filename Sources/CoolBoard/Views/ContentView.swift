import CoolBoardCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ThermalStore

    init(store: ThermalStore) {
        self.store = store
    }

    var body: some View {
        ZStack {
            CoolBoardTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [.white.opacity(0.07), .clear, .white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                ThermalBoardView(store: store)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .font(.system(.body, design: .monospaced))
        .task { store.start() }
        .onDisappear { store.stopAndRestore() }
    }
}
