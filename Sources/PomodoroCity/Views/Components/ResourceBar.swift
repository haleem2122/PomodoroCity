import SwiftUI

public struct ResourceBar: View {
    @ObservedObject var timerManager: TimerManager

    public init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Wood
            ResourceItem(
                icon: "leaf.fill",
                color: Color(red: 0.35, green: 0.72, blue: 0.40),
                label: "Wood",
                amount: timerManager.gameState.resources.wood
            )

            // Stone
            ResourceItem(
                icon: "cube.fill",
                color: Color(red: 0.65, green: 0.68, blue: 0.72),
                label: "Stone",
                amount: timerManager.gameState.resources.stone
            )

            // Metal
            ResourceItem(
                icon: "gearshape.fill",
                color: Color(red: 0.95, green: 0.75, blue: 0.30),
                label: "Metal",
                amount: timerManager.gameState.resources.metal
            )

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))

            // Streak
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .foregroundColor(timerManager.gameState.currentStreakDays > 0 ? .orange : .gray)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(timerManager.gameState.currentStreakDays) Day Streak")
                        .font(.system(size: 12, weight: .bold))
                    Text("Best: \(timerManager.gameState.bestStreakDays)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))

            // Lifetime Focus Hours
            HStack(spacing: 5) {
                Image(systemName: "hourglass")
                    .foregroundColor(.teal)
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(format: "%.1f hrs", timerManager.gameState.lifetimeFocusHours))
                        .font(.system(size: 12, weight: .bold))
                    Text("Lifetime Focus")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Next Reward Progress
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Next Block: +2🪵 +1🪨")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    ProgressView(value: timerManager.gameState.progressTowardNextBlock)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .frame(width: 90)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

private struct ResourceItem: View {
    let icon: String
    let color: Color
    let label: String
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 13, weight: .semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(amount)")
                    .font(.system(size: 13, weight: .bold))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}
