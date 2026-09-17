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

    @State private var confirmingDelete = false

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
                    Button("Delete all sessions and scans", role: .destructive) {
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
                Text("This removes every exercise session and face scan. It can't be undone.")
            }
        }
    }

    private func deleteAll() {
        try? modelContext.delete(model: ExerciseSession.self)
        try? modelContext.delete(model: FaceScan.self)
        try? modelContext.save()
    }
}
