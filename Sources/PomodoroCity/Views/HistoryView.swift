import SwiftUI
import AppKit

public struct HistoryView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false

    public init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Top Resource Bar
                ResourceBar(timerManager: timerManager)

                // Streak & Milestone Highlights
                StreakMilestonesSection(timerManager: timerManager)

                // District Progression
                DistrictsSection(lifetimeHours: timerManager.gameState.lifetimeFocusHours)

                // Backup & Restore
                BackupRestoreSection(
                    onExport: exportBackup,
                    onImport: importBackup
                )

                // Recent Session Records
                SessionsHistorySection(sessions: timerManager.gameState.sessionHistory)
            }
            .padding(24)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Notice"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "PomodoroCityBackup-\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none).replacingOccurrences(of: "/", with: "-")).json"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try SaveManager.shared.exportBackup(state: timerManager.gameState, to: url)
                    alertMessage = "Backup exported successfully to \(url.lastPathComponent)."
                    showAlert = true
                } catch {
                    alertMessage = "Failed to export backup: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try timerManager.restoreFromBackup(url: url)
                    alertMessage = "Save data restored successfully from \(url.lastPathComponent)!"
                    showAlert = true
                } catch {
                    alertMessage = "Failed to restore backup: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

private struct StreakMilestonesSection: View {
    @ObservedObject var timerManager: TimerManager

    let milestones: [(days: Int, name: String, desc: String, icon: String)] = [
        (3, "Bronze Pioneer", "Unlock Bronze Village Lanterns", "shield.fill"),
        (7, "Silver Steward", "Unlock Flowering Cherry Blossom Groves", "star.circle.fill"),
        (14, "Golden Governor", "Unlock Gilded Mayor's Plaza", "crown.fill"),
        (30, "Grand Architect", "Unlock Eternal Flame Monument", "sparkles")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak Milestones & Permanent Rewards")
                .font(.system(size: 16, weight: .bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(milestones, id: \.days) { m in
                    let isUnlocked = timerManager.gameState.milestonesUnlocked.contains(m.days)
                    HStack(spacing: 12) {
                        Image(systemName: m.icon)
                            .font(.system(size: 22))
                            .foregroundColor(isUnlocked ? .yellow : .secondary.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(isUnlocked ? Color.yellow.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(m.days)-Day Streak")
                                    .font(.system(size: 13, weight: .bold))
                                if isUnlocked {
                                    Text("Claimed")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .cornerRadius(4)
                                }
                            }
                            Text(m.desc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        )
    }
}

private struct DistrictsSection: View {
    let lifetimeHours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("District Expansion")
                .font(.system(size: 16, weight: .bold))

            VStack(spacing: 10) {
                DistrictRow(district: .startingVillage, lifetimeHours: lifetimeHours)
                DistrictRow(district: .forestEdge, lifetimeHours: lifetimeHours)
                DistrictRow(district: .riverbank, lifetimeHours: lifetimeHours)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        )
    }
}

private struct DistrictRow: View {
    let district: DistrictID
    let lifetimeHours: Double

    var isUnlocked: Bool {
        return district.isUnlocked(lifetimeHours: lifetimeHours)
    }

    var progress: Double {
        if district.requiredLifetimeHours == 0 { return 1.0 }
        return min(1.0, lifetimeHours / district.requiredLifetimeHours)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                .foregroundColor(isUnlocked ? .green : .secondary)
                .font(.system(size: 20))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(district.name)
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    if isUnlocked {
                        Text("Unlocked")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Text(String(format: "%.1f / %.1f hrs required", lifetimeHours, district.requiredLifetimeHours))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Text(district.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if !isUnlocked {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .teal))
                        .padding(.top, 2)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

private struct BackupRestoreSection: View {
    let onExport: () -> Void
    let onImport: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Local Backup & Restore")
                    .font(.system(size: 14, weight: .bold))
                Text("Export your city and progress to a local JSON file or restore from a backup.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: onExport) {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)

                Button(action: onImport) {
                    Label("Restore Backup", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        )
    }
}

private struct SessionsHistorySection: View {
    let sessions: [SessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed Session History (\(sessions.count))")
                .font(.system(size: 16, weight: .bold))

            if sessions.isEmpty {
                Text("No sessions completed yet. Start your first focus session to grow your city!")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(sessions.prefix(20)) { session in
                        HStack {
                            Image(systemName: session.type == .focus ? "leaf.fill" : "cup.and.saucer.fill")
                                .foregroundColor(session.type == .focus ? .green : .teal)
                                .frame(width: 20)

                            Text(session.type == .focus ? "Focus Session" : "Break")
                                .font(.system(size: 12, weight: .semibold))

                            Spacer()

                            Text(DateFormatter.localizedString(from: session.endTime, dateStyle: .short, timeStyle: .short))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text("\(Int(session.durationSeconds / 60)) mins")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 65, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        )
    }
}
