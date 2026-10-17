import SwiftUI

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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Top Resource Bar
                ResourceBar(timerManager: timerManager)

                // Session Durations
                VStack(alignment: .leading, spacing: 14) {
                    Text("Session Durations")
                        .font(.system(size: 16, weight: .bold))

                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Focus Duration")
                                .font(.system(size: 13, weight: .semibold))
                            Picker("", selection: $focusMinutes) {
                                Text("15 minutes").tag(15)
                                Text("20 minutes").tag(20)
                                Text("25 minutes (Standard)").tag(25)
                                Text("30 minutes").tag(30)
                                Text("45 minutes").tag(45)
                                Text("50 minutes").tag(50)
                                Text("60 minutes").tag(60)
                            }
                            .frame(width: 180)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Break Duration")
                                .font(.system(size: 13, weight: .semibold))
                            Picker("", selection: $breakMinutes) {
                                Text("3 minutes").tag(3)
                                Text("5 minutes (Standard)").tag(5)
                                Text("10 minutes").tag(10)
                                Text("15 minutes").tag(15)
                            }
                            .frame(width: 180)
                        }
                    }

                    Text("Completed focus time accumulates across sessions. Every 25 accumulated minutes awards a full block reward.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                )

                // Evening Streak Reminder
                VStack(alignment: .leading, spacing: 14) {
                    Text("Notifications & Reminders")
                        .font(.system(size: 16, weight: .bold))

                    Toggle("Enable Evening Streak Reminder", isOn: $eveningReminderEnabled)
                        .font(.system(size: 13, weight: .semibold))

                    if eveningReminderEnabled {
                        HStack(spacing: 12) {
                            Text("Reminder Time:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $reminderDate, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }

                        Text("You will receive a gentle reminder at this time only if you have not completed a focus session today. Once you focus, today's reminder is automatically silenced.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    Toggle("Enable Completion Chimes & Sounds", isOn: $soundEnabled)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                )

                // Save button
                HStack {
                    Button(action: saveSettings) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Save Preferences")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)

                    if savedToast {
                        Text("Preferences saved!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }

                    Spacer()
                }
            }
            .padding(24)
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

        withAnimation {
            savedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                savedToast = false
            }
        }
    }
}
