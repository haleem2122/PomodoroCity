import SwiftUI

/// Compact wood / stone / metal counters. (Streak and lifetime hours now live in the sidebar and Progress.)
public struct ResourceBar: View {
    @ObservedObject var timerManager: TimerManager

    public init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    public var body: some View {
        let r = timerManager.gameState.resources
        HStack(spacing: 6) {
            ResourceChip(dot: Theme.wood, label: "Wood", amount: r.wood)
            ResourceChip(dot: Theme.stone, label: "Stone", amount: r.stone)
            ResourceChip(dot: Theme.metal, label: "Metal", amount: r.metal)
        }
    }
}
