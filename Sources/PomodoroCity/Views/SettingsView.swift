import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var focusMinutes: Int = 25
    @State private var breakMinutes: Int = 5
    @State private var eveningReminderEnabled: Bool = true
    @State private var reminderDate: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var soundEnabled: Bool = true
    @State private var savedToast: Bool = false

    public init(timerManager: TimerManager) {
        self.timerManager = timerManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            PageHeader("Settings") {
                ResourceBar(timerManager: timerManager)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Session durations
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle("Sessions").padding(.bottom, 6)

                        SettingRow(title: "Focus length", note: "Every 25 accumulated focus minutes earns one block.") {
                            Picker("", selection: $focusMinutes) {
                                Text("15 minutes").tag(15)
                                Text("20 minutes").tag(20)
                                Text("25 minutes (standard)").tag(25)
                                Text("30 minutes").tag(30)
                                Text("45 minutes").tag(45)
                                Text("50 minutes").tag(50)
                                Text("60 minutes").tag(60)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 190)
                        }
                        Divider().overlay(Theme.line)
                        SettingRow(title: "Break length", note: nil) {
                            Picker("", selection: $breakMinutes) {
                                Text("3 minutes").tag(3)
                                Text("5 minutes (standard)").tag(5)
                                Text("10 minutes").tag(10)
                                Text("15 minutes").tag(15)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 190)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()

                    // Notifications & sound
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle("Reminders and sounds").padding(.bottom, 6)

                        SettingRow(title: "Evening streak reminder",
                                   note: "Sent only if you have not focused today. Focusing silences it automatically.") {
                            Toggle("", isOn: $eveningReminderEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .tint(Theme.sage)
                        }
                        if eveningReminderEnabled {
                            Divider().overlay(Theme.line)
                            SettingRow(title: "Reminder time", note: nil) {
                                DatePicker("", selection: $reminderDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        Divider().overlay(Theme.line)
                        SettingRow(title: "Completion chimes and sounds", note: nil) {
                            Toggle("", isOn: $soundEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .tint(Theme.sage)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()

                    BackupCard(timerManager: timerManager)

                    HStack(spacing: 12) {
                        Button(action: saveSettings) {
                            Label("Save preferences", systemImage: "checkmark")
                        }
                        .buttonStyle(PillButtonStyle(kind: .primary))

                        if savedToast {
                            Text("Preferences saved")
                                .font(Theme.sans(12.5, .medium))
                                .foregroundColor(Theme.sageDeep)
                                .transition(.opacity)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .padding(.top, 4)
                .frame(maxWidth: 760, alignment: .leading)
            }
        }
        .onAppear {
            let s = timerManager.gameState.settings
            self.focusMinutes = s.focusDurationMinutes
            self.breakMinutes = s.breakDurationMinutes
            self.eveningReminderEnabled = s.eveningReminderEnabled
            self.soundEnabled = s.soundEnabled

            var comps = DateComponents()
            comps.hour = s.eveningReminderHour
            comps.minute = s.eveningReminderMinute
            if let date = Calendar.current.date(from: comps) {
                self.reminderDate = date
            }
        }
    }

    private func saveSettings() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: reminderDate)
        let minute = calendar.component(.minute, from: reminderDate)

        let newSettings = AppSettings(
            focusDurationMinutes: focusMinutes,
            breakDurationMinutes: breakMinutes,
            eveningReminderEnabled: eveningReminderEnabled,
            eveningReminderHour: hour,
            eveningReminderMinute: minute,
            soundEnabled: soundEnabled
        )

        timerManager.updateSettings(newSettings)
        NotificationManager.shared.requestAuthorization()

        withAnimation { savedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { savedToast = false }
        }
    }
}

private struct SettingRow<Control: View>: View {
    let title: String
    let note: String?
    let control: Control

    init(title: String, note: String?, @ViewBuilder control: () -> Control) {
        self.title = title
        self.note = note
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.sans(13.5, .medium))
                    .foregroundColor(Theme.ink)
                if let note = note {
                    Text(note)
                        .font(Theme.sans(12))
                        .foregroundColor(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
        }
        .padding(.vertical, 10)
    }
}

/// Local backup / restore (moved here from the old History screen; behaviour unchanged).
private struct BackupCard: View {
    @ObservedObject var timerManager: TimerManager
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your data")
                    .font(Theme.serif(17, .medium))
                    .foregroundColor(Theme.ink)
                Text("Export your city and progress to a file on this Mac, or restore from a backup. Nothing leaves your computer.")
                    .font(Theme.sans(12))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(action: exportBackup) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SmallButtonStyle())
            Button(action: importBackup) {
                Label("Restore", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(SmallButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
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
