import SwiftUI
import SpriteKit

@main
struct PomodoroCityApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 960, height: 700)
    }
}
