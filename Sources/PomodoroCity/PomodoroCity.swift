import SwiftUI
import SpriteKit

@main
struct PomodoroCityApp: App {
    init() {
        // Test/screenshot hook only: lets automated runs use a throwaway save folder.
        if let dir = ProcessInfo.processInfo.environment["POMODORO_SAVE_DIR"], !dir.isEmpty {
            SaveManager.shared.customBaseDirectory = URL(fileURLWithPath: dir, isDirectory: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 720)
    }
}
