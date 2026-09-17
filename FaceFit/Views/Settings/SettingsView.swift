import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.voiceCoach) private var voiceCoach = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.showMesh) private var showMesh = true
    @AppStorage(SettingsKey.difficulty) private var difficulty = 1.0
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = true
    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderMinutes) private var reminderMinutes = 19 * 60
    @AppStorage(SettingsKey.challengeHighScore) private var challengeHighScore = 0
    @AppStorage(SettingsKey.challengeGames) private var challengeGames = 0

    @State private var confirmingDelete = false
    @State private var notificationsDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Voice coach", isOn: $voiceCoach)
                    Toggle("Haptic feedback", isOn: $haptics)
                } header: {
                    Text("Coaching")
                } footer: {
                    Text("Voice cues let you follow exercises with your eyes closed or head turned.")
                }

                Section {
                    Picker("Difficulty", selection: $difficulty) {
                        Text("Gentle").tag(0.75)
                        Text("Standard").tag(1.0)
                        Text("Intense").tag(1.25)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Targets")
                } footer: {
                    Text("Gentle lowers every activation target by 25% — a good start if your face tires quickly or you are rebuilding strength.")
                }

                Section {
                    Toggle("Daily reminder", isOn: reminderToggle)
                    if reminderEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    Text(notificationsDenied
                         ? "Notifications are off for FaceFit. Turn them on in iPhone Settings → Notifications → FaceFit."
                         : "A gentle nudge once a day to keep your streak going.")
                }

                Section("Display") {
                    Toggle("Show 3D face mesh", isOn: $showMesh)
                }

                Section("Camera") {
                    LabeledContent("TrueDepth camera", value: FaceTracker.isTrueDepthAvailable ? "Available" : "Not available (demo mode)")
                }

                Section {
                    Button("Show introduction again") {
                        hasOnboarded = false
                        dismiss()
                    }
                    Button("Delete all sessions, scans and tests", role: .destructive) {
                        confirmingDelete = true
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("All data stays on this iPhone. FaceFit never uploads images or face data.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Text("FaceFit is a wellness and training tool, not a medical device. It does not diagnose or treat any condition. If you have facial paralysis, TMJ disorder or pain, consult a clinician before exercising.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all FaceFit data?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive, action: deleteAll)
            } message: {
                Text("This removes every exercise session, face scan, eye test and challenge score. It can't be undone.")
            }
        }
    }

    private var reminderToggle: Binding<Bool> {
        Binding(
            get: { reminderEnabled },
            set: { isOn in
                reminderEnabled = isOn
                notificationsDenied = false
                if isOn {
                    let minutes = reminderMinutes
                    Task { @MainActor in
                        if !(await ReminderScheduler.enable(minutesAfterMidnight: minutes)) {
                            reminderEnabled = false
                            notificationsDenied = true
                        }
                    }
                } else {
                    ReminderScheduler.disable()
                }
            }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60,
                                      second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (parts.hour ?? 19) * 60 + (parts.minute ?? 0)
                if reminderEnabled {
                    ReminderScheduler.schedule(minutesAfterMidnight: reminderMinutes)
                }
            }
        )
    }

    private func deleteAll() {
        try? modelContext.delete(model: ExerciseSession.self)
        try? modelContext.delete(model: FaceScan.self)
        try? modelContext.delete(model: BlinkTest.self)
        try? modelContext.save()
        challengeHighScore = 0
        challengeGames = 0
    }
}
