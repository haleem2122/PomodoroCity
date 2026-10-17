import SwiftUI

public enum AppTab: String, CaseIterable, Identifiable {
    case focus
    case city
    case history
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .focus: return "Focus Timer"
        case .city: return "City Map"
        case .history: return "History & Badges"
        case .settings: return "Settings"
        }
    }

    public var icon: String {
        switch self {
        case .focus: return "timer"
        case .city: return "map"
        case .history: return "rosette"
        case .settings: return "gearshape"
        }
    }
}

public struct MainTabView: View {
    @StateObject private var timerManager = TimerManager()
    @State private var selectedTab: AppTab = .focus

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // macOS Window Toolbar / Segmented Navigation
            HStack {
                // App Logo / Title
                HStack(spacing: 8) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.45))
                        .font(.system(size: 20))
                    Text("Pomodoro City")
                        .font(.system(size: 15, weight: .bold))
                }

                Spacer()

                // Navigation Segmented Buttons
                HStack(spacing: 2) {
                    ForEach(AppTab.allCases) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 12))
                                Text(tab.title)
                                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedTab == tab ?
                                    Color.accentColor.opacity(0.18) :
                                    Color.clear
                            )
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Main Active View
            ZStack {
                switch selectedTab {
                case .focus:
                    FocusView(timerManager: timerManager) {
                        withAnimation {
                            selectedTab = .city
                        }
                    }
                case .city:
                    CityView(timerManager: timerManager)
                case .history:
                    HistoryView(timerManager: timerManager)
                case .settings:
                    SettingsView(timerManager: timerManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 880, minHeight: 640)
        .onAppear {
            NotificationManager.shared.requestAuthorization()
        }
    }
}
