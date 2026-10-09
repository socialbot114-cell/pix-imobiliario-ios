import SwiftUI

@main
struct BancoDoTabuleiroApp: App {
    @StateObject private var gameStore = GameStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameStore)
                .preferredColorScheme(.light)
        }
    }
}
