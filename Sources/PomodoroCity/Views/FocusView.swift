import SwiftUI

public struct FocusView: View {
    @ObservedObject var timerManager: TimerManager
    let onNavigateToCity: () -> Void

    public init(timerManager: TimerManager, onNavigateToCity: @escaping () -> Void) {
        self.timerManager = timerManager
        self.onNavigateToCity = onNavigateToCity
    }

    // MARK: Derived values

    private var gs: GameState { timerManager.gameState }

    /// Non-nil only while the timer is idle right after a session finished.
    private var completion: SessionCompletion? {
        timerManager.timerState == .idle ? timerManager.lastCompletion : nil
    }

    private var formattedTime: String {
        let total = Int(timerManager.timeRemaining)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var progressRatio: Double {
        if completion != nil { return 1 }
        guard timerManager.totalSessionDuration > 0 else { return 0 }
        let elapsed = timerManager.totalSessionDuration - timerManager.timeRemaining
        return min(1.0, max(0.0, elapsed / timerManager.totalSessionDuration))
    }

    private var isBreak: Bool {
        timerManager.timerState == .runningBreak || timerManager.timerState == .pausedBreak
    }

    private var isFocusMode: Bool { !isBreak }

    private var accent: Color { isBreak ? Theme.rest : Theme.sage }

    private var statusTitle: String {
        if let c = completion { return c.isFocus ? "Session complete" : "Break over" }
        switch timerManager.timerState {
        case .idle: return "Ready to focus"
        case .runningFocus: return "Focusing"
        case .pausedFocus: return "Focus paused"
        case .runningBreak: return "Break time"
        case .pausedBreak: return "Break paused"
        }
    }

    private var isRunning: Bool {
        timerManager.timerState == .runningFocus || timerManager.timerState == .runningBreak
    }

    private var todayFocusMinutes: Int {
        let start = Calendar.current.startOfDay(for: Date())
        let seconds = gs.sessionHistory
            .filter { $0.type == .focus && $0.endTime >= start }
            .reduce(0.0) { $0 + $1.durationSeconds }
        return Int(seconds / 60.0)
    }

    private var minutesTowardNextBlock: Int { Int(gs.secondsTowardNextBlock / 60) }

    private var nextLockedDistrict: DistrictID? {
        [DistrictID.forestEdge, .riverbank].first { !$0.isUnlocked(lifetimeHours: gs.lifetimeFocusHours) }
    }

    // MARK: Body

    public var body: some View {
        VStack(spacing: 0) {
            PageHeader("Focus") {
                ResourceBar(timerManager: timerManager)
            }

            GeometryReader { geo in
                let dial = min(320, max(210, geo.size.height - 250))
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    statusLabel
                    TimerDial(
                        progress: progressRatio,
                        accent: accent,
                        size: dial,
                        isComplete: completion != nil,
                        time: formattedTime,
                        title: completionTitle,
                        subtitle: dialSubtitle,
                        isRunning: isRunning
                    )
                    middleRow
                    controls
                    caption
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }

            cityCard
                .padding(.horizontal, 28)
                .padding(.bottom, 22)
        }
        .animation(.easeInOut(duration: 0.25), value: completion?.id)
    }

    // MARK: Pieces

    private var statusLabel: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)
                .opacity(isRunning ? 0.9 : 1)
            Text(statusTitle)
                .font(Theme.sans(12, .medium))
                .tracking(1.3)
                .textCase(.uppercase)
                .foregroundColor(isBreak ? Theme.rest : Theme.sageDeep)
        }
    }

    private var completionTitle: String {
        guard let c = completion else { return "" }
        return c.isFocus ? "Well done" : "Refreshed"
    }

    private var dialSubtitle: String {
        if let c = completion {
            return c.isFocus ? "\(c.minutes) minutes focused" : "Ready when you are"
        }
        return isFocusMode ? "Focus block" : "Rest & recharge"
    }

    @ViewBuilder
    private var middleRow: some View {
        if let c = completion {
            VStack(spacing: 8) {
                if c.isFocus {
                    HStack(spacing: 8) {
                        if c.reward.wood > 0 { rewardChip(Theme.wood, "+\(c.reward.wood) Wood") }
                        if c.reward.stone > 0 { rewardChip(Theme.stone, "+\(c.reward.stone) Stone") }
                        if c.reward.metal > 0 { rewardChip(Theme.metal, "+\(c.reward.metal) Metal") }
                    }
                    Text(c.blocksEarned > 0
                         ? "\(c.blocksEarned) focus block\(c.blocksEarned > 1 ? "s" : "") added to your city"
                         : "Counted toward your next focus block")
                        .font(Theme.sans(12.5))
                        .foregroundColor(Theme.muted)
                }
            }
        } else if timerManager.timerState == .idle {
            HStack(spacing: 6) {
                DurationChip(title: "25 min", isSelected: gs.settings.focusDurationMinutes == 25) {
                    var s = gs.settings; s.focusDurationMinutes = 25; timerManager.updateSettings(s)
                }
                DurationChip(title: "50 min", isSelected: gs.settings.focusDurationMinutes == 50) {
                    var s = gs.settings; s.focusDurationMinutes = 50; timerManager.updateSettings(s)
                }
                DurationChip(title: "5 min break", isSelected: gs.settings.breakDurationMinutes == 5) {
                    var s = gs.settings; s.breakDurationMinutes = 5; timerManager.updateSettings(s)
                }
            }
        } else {
            Color.clear.frame(height: 26)
        }
    }

    private func rewardChip(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(Theme.sans(12.5, .medium)).foregroundColor(Theme.sageDeep)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.sageSoft))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if let c = completion {
                if c.isFocus {
                    Button { timerManager.startBreak() } label: { Label("Start break", systemImage: "cup.and.saucer.fill") }
                        .buttonStyle(PillButtonStyle(kind: .sage))
                    Button { onNavigateToCity() } label: { Text("Visit city") }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                } else {
                    Button { timerManager.startFocus() } label: { Label("Start focus", systemImage: "play.fill") }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                }
                Button { timerManager.lastCompletion = nil } label: { Text("Done") }
                    .buttonStyle(.plain)
                    .font(Theme.sans(13, .medium))
                    .foregroundColor(Theme.muted)
                    .padding(.leading, 6)
            } else {
                switch timerManager.timerState {
                case .idle:
                    Button { timerManager.startFocus() } label: { Label("Start focus", systemImage: "play.fill") }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                    Button { timerManager.startBreak() } label: { Label("Short break", systemImage: "cup.and.saucer.fill") }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                case .runningFocus, .runningBreak:
                    Button { timerManager.pause() } label: { Label("Pause", systemImage: "pause.fill") }
                        .buttonStyle(PillButtonStyle(kind: .primary))
                    Button { timerManager.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                case .pausedFocus, .pausedBreak:
                    Button { timerManager.resume() } label: { Label("Resume", systemImage: "play.fill") }
                        .buttonStyle(PillButtonStyle(kind: .sage))
                    Button { timerManager.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                }
            }
        }
        .padding(.top, 2)
    }

    private var caption: some View {
        Text("Today \(todayFocusMinutes) min focused  ·  \(minutesTowardNextBlock) of 25 min toward your next block")
            .font(Theme.sans(12))
            .foregroundColor(Theme.muted)
            .monospacedDigit()
    }

    private var cityCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "house.lodge")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(Theme.sageDeep)
                .frame(width: 46, height: 40)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.sageSoft))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Your city")
                        .font(Theme.sans(13, .semibold))
                        .foregroundColor(Theme.ink)
                    Text("· \(gs.buildings.count) buildings")
                        .font(Theme.sans(12.5))
                        .foregroundColor(Theme.muted)
                }
                if let d = nextLockedDistrict {
                    let required = d.requiredLifetimeHours
                    Text(String(format: "%@ unlocks at %.0f focus hours  ·  %.1f / %.0f h", d.name, required, gs.lifetimeFocusHours, required))
                        .font(Theme.sans(12))
                        .foregroundColor(Theme.muted)
                        .monospacedDigit()
                    MeterBar(value: gs.lifetimeFocusHours / required)
                } else {
                    Text("All districts unlocked")
                        .font(Theme.sans(12))
                        .foregroundColor(Theme.muted)
                    MeterBar(value: 1)
                }
            }

            Button(action: onNavigateToCity) {
                HStack(spacing: 4) {
                    Text("Visit city")
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(SmallButtonStyle())
        }
        .themedCard(padding: 14)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Timer dial

private struct TimerDial: View {
    let progress: Double
    let accent: Color
    let size: CGFloat
    let isComplete: Bool
    let time: String
    let title: String
    let subtitle: String
    let isRunning: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.line, lineWidth: 10)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)

            VStack(spacing: 6) {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(Theme.sageDeep)
                    Text(title)
                        .font(Theme.serif(34, .regular))
                        .foregroundColor(Theme.ink)
                } else {
                    Text(time)
                        .font(Theme.serif(size * 0.24, .regular))
                        .monospacedDigit()
                        .foregroundColor(Theme.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(Theme.sans(13))
                    .foregroundColor(Theme.muted)
            }
        }
        .padding(5)
        .frame(width: size, height: size)
    }
}

// MARK: - Duration chips

private struct DurationChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(12.5, .medium))
                .foregroundColor(isSelected ? Theme.ink : (hovering ? Theme.ink : Theme.muted))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(isSelected ? Theme.raised : Color.clear))
                .overlay(Capsule().stroke(isSelected ? Theme.line : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
