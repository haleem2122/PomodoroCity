import SwiftUI

public struct FocusView: View {
    @ObservedObject var timerManager: TimerManager
    let onNavigateToCity: () -> Void

    public init(timerManager: TimerManager, onNavigateToCity: @escaping () -> Void) {
        self.timerManager = timerManager
        self.onNavigateToCity = onNavigateToCity
    }

    private var formattedTime: String {
        let total = Int(timerManager.timeRemaining)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var progressRatio: Double {
        guard timerManager.totalSessionDuration > 0 else { return 0 }
        let elapsed = timerManager.totalSessionDuration - timerManager.timeRemaining
        return min(1.0, max(0.0, elapsed / timerManager.totalSessionDuration))
    }

    private var isFocusMode: Bool {
        return timerManager.timerState == .runningFocus ||
               timerManager.timerState == .pausedFocus ||
               timerManager.timerState == .idle
    }

    private var statusBadgeTitle: String {
        switch timerManager.timerState {
        case .idle:
            return "Ready to Focus"
        case .runningFocus:
            return "Focusing..."
        case .pausedFocus:
            return "Focus Paused"
        case .runningBreak:
            return "Break Time"
        case .pausedBreak:
            return "Break Paused"
        }
    }

    private var todayFocusMinutes: Int {
        let today = DateFormatter()
        today.dateFormat = "yyyy-MM-dd"
        today.timeZone = TimeZone.current
        let todayStr = today.string(from: Date())

        let seconds = timerManager.gameState.sessionHistory
            .filter { $0.type == .focus && $0.calendarDayString == todayStr }
            .reduce(0.0) { $0 + $1.durationSeconds }
        return Int(seconds / 60.0)
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Top Resource Header
            ResourceBar(timerManager: timerManager)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Spacer()

            // Timer Central Widget
            VStack(spacing: 16) {
                // Mode indicator badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 8, height: 8)
                    Text(statusBadgeTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(badgeColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(badgeColor.opacity(0.12))
                )

                // Large Progress Ring & Countdown
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 14)
                        .frame(width: 260, height: 260)

                    Circle()
                        .trim(from: 0, to: CGFloat(progressRatio))
                        .stroke(
                            ringGradient,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 260, height: 260)
                        .animation(.linear(duration: 0.5), value: progressRatio)

                    VStack(spacing: 6) {
                        Text(formattedTime)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text(isFocusMode ? "Focus Block" : "Rest & Recharge")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                // Preset Duration Chips (when timer is idle)
                if timerManager.timerState == .idle {
                    HStack(spacing: 8) {
                        DurationButton(title: "25m Focus", minutes: 25, isSelected: timerManager.gameState.settings.focusDurationMinutes == 25) {
                            var s = timerManager.gameState.settings
                            s.focusDurationMinutes = 25
                            timerManager.updateSettings(s)
                        }
                        DurationButton(title: "50m Focus", minutes: 50, isSelected: timerManager.gameState.settings.focusDurationMinutes == 50) {
                            var s = timerManager.gameState.settings
                            s.focusDurationMinutes = 50
                            timerManager.updateSettings(s)
                        }
                        DurationButton(title: "5m Break", minutes: 5, isSelected: timerManager.gameState.settings.breakDurationMinutes == 5) {
                            var s = timerManager.gameState.settings
                            s.breakDurationMinutes = 5
                            timerManager.updateSettings(s)
                        }
                    }
                    .padding(.top, 4)
                }

                // Primary Controls
                HStack(spacing: 16) {
                    switch timerManager.timerState {
                    case .idle:
                        Button(action: {
                            timerManager.startFocus()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start Focus")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 150, height: 42)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.28, green: 0.65, blue: 0.40))

                        Button(action: {
                            timerManager.startBreak()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "cup.and.saucer.fill")
                                Text("Short Break")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 130, height: 42)
                        }
                        .buttonStyle(.bordered)

                    case .runningFocus, .runningBreak:
                        Button(action: {
                            timerManager.pause()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pause.fill")
                                Text("Pause")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 130, height: 42)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button(action: {
                            timerManager.reset()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 110, height: 42)
                        }
                        .buttonStyle(.bordered)

                    case .pausedFocus, .pausedBreak:
                        Button(action: {
                            timerManager.resume()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Resume")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 130, height: 42)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.28, green: 0.65, blue: 0.40))

                        Button(action: {
                            timerManager.reset()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 110, height: 42)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.top, 8)
            }

            Spacer()

            // Bottom Bar: Today's Stats & Direct Jump to City
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Focus Time")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("\(todayFocusMinutes) minutes completed")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }

                Spacer()

                // Visit City Button
                Button(action: onNavigateToCity) {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14))
                        Text("Visit Your City")
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.65, blue: 0.45), Color(red: 0.25, green: 0.55, blue: 0.38)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
        }
    }

    private var badgeColor: Color {
        switch timerManager.timerState {
        case .idle: return .blue
        case .runningFocus: return Color(red: 0.28, green: 0.72, blue: 0.45)
        case .pausedFocus: return .orange
        case .runningBreak: return .teal
        case .pausedBreak: return .orange
        }
    }

    private var ringGradient: LinearGradient {
        if isFocusMode {
            return LinearGradient(
                colors: [Color(red: 0.35, green: 0.75, blue: 0.50), Color(red: 0.20, green: 0.60, blue: 0.40)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.teal, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct DurationButton: View {
    let title: String
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
