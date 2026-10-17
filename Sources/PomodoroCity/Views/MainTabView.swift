import SwiftUI

public enum AppTab: String, CaseIterable, Identifiable {
    case focus
    case city
    case history
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .focus: return "Focus"
        case .city: return "City"
        case .history: return "Progress"
        case .settings: return "Settings"
        }
    }

    public var icon: String {
        switch self {
        case .focus: return "timer"
        case .city: return "building.2"
        case .history: return "chart.bar"
        case .settings: return "slider.horizontal.3"
        }
    }
}

public struct MainTabView: View {
    @StateObject private var timerManager = TimerManager()
    @State private var selectedTab: AppTab = MainTabView.initialTab()

    public init() {}

    private static func initialTab() -> AppTab {
        // Test/screenshot hook only.
        if let raw = ProcessInfo.processInfo.environment["POMODORO_TAB"], let tab = AppTab(rawValue: raw) {
            return tab
        }
        return .focus
    }

    private func select(_ tab: AppTab) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = tab
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            SidebarView(selected: selectedTab, timerManager: timerManager, onSelect: select)

            Rectangle()
                .fill(Theme.line)
                .frame(width: 1)
                .ignoresSafeArea()

            ZStack {
                switch selectedTab {
                case .focus:
                    FocusView(timerManager: timerManager) { select(.city) }
                        .transition(.opacity)
                case .city:
                    CityView(timerManager: timerManager)
                        .transition(.opacity)
                case .history:
                    HistoryView(timerManager: timerManager)
                        .transition(.opacity)
                case .settings:
                    SettingsView(timerManager: timerManager)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.surface.ignoresSafeArea())
        }
        .background(Theme.bg.ignoresSafeArea())
        .frame(minWidth: 900, minHeight: 640)
        .onAppear {
            NotificationManager.shared.requestAuthorization()
            if ProcessInfo.processInfo.environment["POMODORO_DEMO_COMPLETE"] == "1" {
                // Screenshot hook only.
                timerManager.lastCompletion = SessionCompletion(
                    isFocus: true, minutes: 25, blocksEarned: 1,
                    reward: Resources(wood: 2, stone: 1, metal: 1)
                )
            }
        }
    }
}

// MARK: - Sidebar

private struct SidebarView: View {
    let selected: AppTab
    @ObservedObject var timerManager: TimerManager
    let onSelect: (AppTab) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Theme.sageDeep)
                Text("Pomodoro City")
                    .font(Theme.serif(17, .medium))
                    .foregroundColor(Theme.ink)
            }
            .padding(.horizontal, 10)
            .padding(.top, 38)
            .padding(.bottom, 18)

            ForEach(Array(AppTab.allCases.enumerated()), id: \.element.id) { index, tab in
                SidebarRow(tab: tab, isSelected: selected == tab) { onSelect(tab) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(Theme.line).frame(height: 1)
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundColor(timerManager.gameState.currentStreakDays > 0 ? Color(nsColor: NSColor(hex: 0xC98A4B)) : Theme.muted)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(streakText)
                            .font(Theme.sans(12.5, .semibold))
                            .foregroundColor(Theme.ink)
                        Text(String(format: "%.1f focus hours", timerManager.gameState.lifetimeFocusHours))
                            .font(Theme.sans(11))
                            .foregroundColor(Theme.muted)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 12)
        .frame(width: 196)
        .background(Theme.bg.ignoresSafeArea())
    }

    private var streakText: String {
        let n = timerManager.gameState.currentStreakDays
        return n == 1 ? "1 day streak" : "\(n) day streak"
    }
}

private struct SidebarRow: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 18)
                Text(tab.title)
                    .font(Theme.sans(13.5, .medium))
                Spacer()
            }
            .foregroundColor(isSelected ? Theme.sageDeep : (hovering ? Theme.ink : Theme.muted))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.sageSoft : (hovering ? Theme.line.opacity(0.55) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
