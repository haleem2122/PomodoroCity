import SwiftUI

/// "Progress" tab: statistics, weekly focus, districts, streak rewards and session history.
public struct HistoryView: View {
    @ObservedObject var timerManager: TimerManager

    public init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    private var gs: GameState { timerManager.gameState }

    public var body: some View {
        VStack(spacing: 0) {
            PageHeader("Progress") {
                ResourceBar(timerManager: timerManager)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        StatTile(value: String(format: "%.1f h", gs.lifetimeFocusHours), label: "Lifetime focus")
                        StatTile(value: "\(gs.currentStreakDays) day\(gs.currentStreakDays == 1 ? "" : "s")",
                                 label: "Current streak · best \(gs.bestStreakDays)")
                        StatTile(value: "\(gs.completedFocusBlocks)", label: "Focus blocks earned")
                    }

                    HStack(alignment: .top, spacing: 14) {
                        WeekChart(sessions: gs.sessionHistory)
                        DistrictsSection(lifetimeHours: gs.lifetimeFocusHours)
                    }

                    StreakMilestonesSection(unlocked: gs.milestonesUnlocked, current: gs.currentStreakDays)

                    SessionsHistorySection(sessions: gs.sessionHistory)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Pieces

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.serif(30, .medium))
                .monospacedDigit()
                .foregroundColor(Theme.ink)
            Text(label)
                .font(Theme.sans(12))
                .foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: 16)
    }
}

private struct WeekChart: View {
    let sessions: [SessionRecord]

    private struct Day: Identifiable {
        let id: Int
        let label: String
        let minutes: Int
        let isToday: Bool
    }

    private var days: [Day] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEEE"
        var totals: [Date: Double] = [:]
        for s in sessions where s.type == .focus {
            totals[cal.startOfDay(for: s.endTime), default: 0] += s.durationSeconds
        }
        return (0..<7).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return Day(id: offset, label: fmt.string(from: d), minutes: Int((totals[d] ?? 0) / 60), isToday: offset == 0)
        }
    }

    var body: some View {
        let data = days
        let peak = max(60, data.map(\.minutes).max() ?? 60)
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("This week")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(data) { d in
                    VStack(spacing: 5) {
                        Text(d.minutes > 0 ? "\(d.minutes)" : " ")
                            .font(Theme.sans(10))
                            .monospacedDigit()
                            .foregroundColor(Theme.muted)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(d.isToday ? Theme.sage : Theme.sageSoft)
                            .frame(height: max(4, 80 * CGFloat(d.minutes) / CGFloat(peak)))
                        Text(d.label)
                            .font(Theme.sans(11))
                            .foregroundColor(d.isToday ? Theme.ink : Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 112, alignment: .bottom)
            Text("Minutes of focus per day")
                .font(Theme.sans(11))
                .foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}

private struct DistrictsSection: View {
    let lifetimeHours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("Districts").padding(.bottom, 4)
            ForEach(Array(DistrictID.allCases.enumerated()), id: \.element.id) { index, d in
                if index > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                DistrictRow(district: d, lifetimeHours: lifetimeHours)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}

private struct DistrictRow: View {
    let district: DistrictID
    let lifetimeHours: Double

    private var isUnlocked: Bool { district.isUnlocked(lifetimeHours: lifetimeHours) }
    private var progress: Double {
        district.requiredLifetimeHours == 0 ? 1 : min(1, lifetimeHours / district.requiredLifetimeHours)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isUnlocked ? Theme.sage : Theme.muted)
                Text(district.name)
                    .font(Theme.sans(13, .semibold))
                    .foregroundColor(Theme.ink)
                Spacer()
                Text(isUnlocked ? "Unlocked" : String(format: "%.1f / %.0f h", lifetimeHours, district.requiredLifetimeHours))
                    .font(Theme.sans(12))
                    .monospacedDigit()
                    .foregroundColor(Theme.muted)
            }
            if !isUnlocked {
                MeterBar(value: progress)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct StreakMilestonesSection: View {
    let unlocked: [Int]
    let current: Int

    private let milestones: [(days: Int, name: String, desc: String, icon: String)] = [
        (3, "Bronze Pioneer", "Unlock Bronze Village Lanterns", "shield.fill"),
        (7, "Silver Steward", "Unlock Flowering Cherry Blossom Groves", "star.circle.fill"),
        (14, "Golden Governor", "Unlock Gilded Mayor's Plaza", "crown.fill"),
        (30, "Grand Architect", "Unlock Eternal Flame Monument", "sparkles")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Streak milestones")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(milestones, id: \.days) { m in
                    let isUnlocked = unlocked.contains(m.days)
                    HStack(spacing: 12) {
                        Image(systemName: m.icon)
                            .font(.system(size: 16))
                            .foregroundColor(isUnlocked ? Theme.sageDeep : Theme.muted.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(isUnlocked ? Theme.sageSoft : Theme.line.opacity(0.5)))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("\(m.days)-day streak")
                                    .font(Theme.sans(13, .semibold))
                                    .foregroundColor(Theme.ink)
                                if isUnlocked {
                                    Text("Claimed")
                                        .font(Theme.sans(10, .semibold))
                                        .foregroundColor(Theme.sageDeep)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Theme.sageSoft))
                                } else if current > 0 {
                                    Text("\(max(0, m.days - current)) to go")
                                        .font(Theme.sans(10.5))
                                        .foregroundColor(Theme.muted)
                                }
                            }
                            Text(m.desc)
                                .font(Theme.sans(11.5))
                                .foregroundColor(Theme.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}

private struct SessionsHistorySection: View {
    let sessions: [SessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Recent sessions")
            if sessions.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "Nothing here yet",
                    message: "Finish your first focus session and it will appear here, along with the resources it earns for your city."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.prefix(20).enumerated()), id: \.element.id) { index, session in
                        if index > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                        HStack(spacing: 10) {
                            Image(systemName: session.type == .focus ? "leaf.fill" : "cup.and.saucer.fill")
                                .font(.system(size: 12))
                                .foregroundColor(session.type == .focus ? Theme.sage : Theme.rest)
                                .frame(width: 18)
                            Text(session.type == .focus ? "Focus session" : "Break")
                                .font(Theme.sans(13, .medium))
                                .foregroundColor(Theme.ink)
                            Spacer()
                            Text(DateFormatter.localizedString(from: session.endTime, dateStyle: .medium, timeStyle: .short))
                                .font(Theme.sans(12))
                                .foregroundColor(Theme.muted)
                            Text("\(Int(session.durationSeconds / 60)) min")
                                .font(Theme.sans(12.5, .semibold))
                                .monospacedDigit()
                                .foregroundColor(Theme.ink)
                                .frame(width: 58, alignment: .trailing)
                        }
                        .padding(.vertical, 9)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }
}
