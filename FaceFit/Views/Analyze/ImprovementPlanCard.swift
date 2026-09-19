import SwiftUI
import SwiftData

/// Personal routine built from the scan's weakest areas plus the user's goals.
struct ImprovementPlanCard: View {
    let scores: [RegionScore]

    @Query private var sessions: [ExerciseSession]
    @Query private var scans: [FaceScan]
    @Query private var blinkTests: [BlinkTest]
    @AppStorage(SettingsKey.challengeHighScore) private var challengeHighScore = 0
    @AppStorage(SettingsKey.challengeGames) private var challengeGames = 0

    @AppStorage(SettingsKey.improvementGoals) private var goalsRaw = ""
    @State private var running = false
    @State private var editingGoals = false

    var body: some View {
        let goals = GoalStore.decode(goalsRaw)
        let playerLevel = Progression.level(forXP: Progression.totalXP(
            sessions: sessions, scans: scans, blinkTests: blinkTests,
            challengeGames: challengeGames, challengeHighScore: challengeHighScore))
        let plan = ImprovementPlan.build(scores: scores, goals: goals, playerLevel: playerLevel)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                SectionHeader(title: "Your improvement plan",
                              subtitle: goals.isEmpty ? "Targets your lowest-scoring areas" : "Targets your weakest areas and goals")
                Button {
                    editingGoals = true
                } label: {
                    Label("Goals", systemImage: "target")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if plan.items.isEmpty {
                Text("Every area scored well. Keep training with a program or the daily workout, and set goals to focus on specific areas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(plan.focus) { region in
                            Label(region.title, systemImage: region.symbol)
                                .font(.caption.bold())
                                .foregroundStyle(region.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(region.color.opacity(0.18), in: Capsule())
                        }
                    }
                }

                ForEach(plan.items) { item in
                    NavigationLink {
                        ExerciseDetailView(exercise: item.exercise)
                    } label: {
                        HStack {
                            ExerciseRow(exercise: item.exercise)
                            if let region = item.region {
                                Image(systemName: region.symbol)
                                    .font(.caption)
                                    .foregroundStyle(region.color)
                            } else {
                                Text("Cool-down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button("Start plan · about \(plan.duration.clockString) min") {
                    running = true
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.warm))
            }

            Text("Do your plan most days and scan again every 1–2 weeks to see your scores change. Facial exercises train muscle tone and control; they don't change bone structure.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .card()
        .fullScreenCover(isPresented: $running) {
            ExerciseSessionView(exercises: plan.exercises)
        }
        .sheet(isPresented: $editingGoals) {
            GoalsView()
        }
    }
}

/// Lets the user pick the areas they most want to improve.
struct GoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.improvementGoals) private var goalsRaw = ""

    var body: some View {
        let goals = GoalStore.decode(goalsRaw)
        NavigationStack {
            List {
                Section {
                    ForEach(FaceRegion.allCases) { region in
                        let isSelected = goals.contains(region)
                        Button {
                            toggle(region)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: region.symbol)
                                    .foregroundStyle(region.color)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(region.goalTitle)
                                        .foregroundStyle(Color.primary)
                                    Text(region.goalDetail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Your goals get extra priority when FaceFit builds your plan, even before your first scan.")
                }
            }
            .navigationTitle("Your goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ region: FaceRegion) {
        var goals = GoalStore.decode(goalsRaw)
        if goals.contains(region) {
            goals.remove(region)
        } else {
            goals.insert(region)
        }
        goalsRaw = GoalStore.encode(goals)
    }
}
