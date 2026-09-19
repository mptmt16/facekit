import SwiftUI
import SwiftData

/// "You": personal details that shape the tips, plus shortcuts to your history.
struct ProfileView: View {
    @AppStorage(ProfileKey.name) private var name = ""
    @AppStorage(ProfileKey.age) private var age = 0
    @AppStorage(ProfileKey.water) private var water = 0
    @AppStorage(ProfileKey.sleep) private var sleep = 0.0
    @AppStorage(ProfileKey.screen) private var screen = 0.0

    @Query(sort: \FaceScan.date, order: .reverse) private var scans: [FaceScan]
    @Query private var sessions: [ExerciseSession]
    @Query private var blinkTests: [BlinkTest]
    @AppStorage(SettingsKey.challengeHighScore) private var challengeHighScore = 0

    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Text(initials)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: 88, height: 88)
                            .background(Theme.accent, in: Circle())
                        Text(name.isEmpty ? "Add your name" : name)
                            .font(.title2.bold())
                            .foregroundStyle(name.isEmpty ? Color.secondary : Color.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack(spacing: 12) {
                        StatTile(title: "Day streak", value: "\(sessions.streak)", symbol: "flame.fill", color: Theme.warm)
                        StatTile(title: "Scans", value: "\(scans.count)", symbol: "faceid")
                        StatTile(title: "Reps", value: "\(sessions.totalReps)", symbol: "repeat", color: Theme.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Name", text: $name)
                    Stepper("Age: \(age > 0 ? "\(age)" : "—")", value: $age, in: 0...100)
                    Stepper("Water: \(water) glasses / day", value: $water, in: 0...20)
                    Stepper("Sleep: \(sleep.formatted()) hrs", value: $sleep, in: 0...12, step: 0.5)
                    Stepper("Screen time: \(screen.formatted()) hrs / day", value: $screen, in: 0...16, step: 0.5)
                } header: {
                    Text("Personal info")
                } footer: {
                    Text("Only used to personalise your daily tips. It stays on this iPhone.")
                }

                Section {
                    NavigationLink {
                        CompareScansView()
                    } label: {
                        Label("Before & after", systemImage: "rectangle.on.rectangle")
                    }
                    NavigationLink {
                        AchievementsView()
                    } label: {
                        Label("Achievements", systemImage: "trophy")
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .foregroundStyle(Color.primary)
                    }
                }

                if !scans.isEmpty {
                    Section("Scan history") {
                        ForEach(scans.prefix(5)) { scan in
                            NavigationLink {
                                ScanResultView(scan: scan)
                            } label: {
                                ScanRow(scan: scan)
                            }
                        }
                    }
                }

                if !blinkTests.isEmpty || challengeHighScore > 0 {
                    Section("Other results") {
                        if let test = blinkTests.sorted(by: { $0.date > $1.date }).first {
                            LabeledContent("Eye comfort", value: "\(Int(test.score.rounded()))")
                        }
                        if challengeHighScore > 0 {
                            LabeledContent("Face Challenge best", value: "\(challengeHighScore)")
                        }
                    }
                }
            }
            .navigationTitle("You")
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "🙂" : letters.joined().uppercased()
    }
}
