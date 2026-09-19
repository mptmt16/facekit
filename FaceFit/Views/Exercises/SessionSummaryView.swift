import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    let results: [ExerciseResult]
    var onDone: () -> Void

    @Query private var sessions: [ExerciseSession]
    @Query private var scans: [FaceScan]
    @Query private var blinkTests: [BlinkTest]
    @AppStorage(SettingsKey.challengeHighScore) private var challengeHighScore = 0
    @AppStorage(SettingsKey.challengeGames) private var challengeGames = 0

    private var xpEarned: Int {
        results.reduce(0) { $0 + Progression.xp(reps: $1.repsCompleted, target: $1.exercise.reps, intensity: $1.intensity) }
    }

    private var totalXP: Int {
        Progression.totalXP(sessions: sessions, scans: scans, blinkTests: blinkTests,
                            challengeGames: challengeGames, challengeHighScore: challengeHighScore)
    }

    private var totalReps: Int { results.reduce(0) { $0 + $1.repsCompleted } }
    private var totalTime: TimeInterval { results.reduce(0) { $0 + $1.duration } }

    private var averageSymmetry: Double? {
        let values = results.compactMap(\.symmetry)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var isComplete: Bool {
        results.allSatisfy { $0.repsCompleted >= $0.exercise.reps }
    }

    /// XP earned, the level bar, and anything this session unlocked.
    private var xpCard: some View {
        let after = Progression.progress(forXP: totalXP)
        let before = Progression.progress(forXP: Swift.max(0, totalXP - xpEarned))
        let levelledUp = after.level > before.level
        let unlocked = levelledUp ? Progression.unlocks(atLevel: after.level) : []

        return VStack(spacing: 12) {
            Text("+\(xpEarned) XP")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.warm)
            if levelledUp {
                Label("Level \(after.level) — \(Progression.rank(forLevel: after.level))", systemImage: "arrow.up.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
            }
            VStack(spacing: 4) {
                ProgressView(value: after.fraction).tint(Theme.warm)
                Text("Level \(after.level) · \(after.remaining) XP to level \(after.level + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !unlocked.isEmpty {
                VStack(spacing: 6) {
                    Text("NEW EXERCISES UNLOCKED")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    ForEach(unlocked) { exercise in
                        Label(exercise.name, systemImage: exercise.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(exercise.category.color)
                    }
                }
                .padding(.top, 4)
            }
        }
        .card()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: isComplete ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.warm)
                    .padding(.top, 48)
                Text(isComplete ? "Workout complete" : "Session saved")
                    .font(.largeTitle.bold())
                Text(isComplete ? "Consistency is what reshapes muscle — see you tomorrow."
                                : "Every rep counts. Finish the full set next time for the best results.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                xpCard

                HStack(spacing: 12) {
                    StatTile(title: "Reps", value: "\(totalReps)", symbol: "repeat")
                    StatTile(title: "Time", value: totalTime.clockString, symbol: "timer", color: Theme.secondary)
                    StatTile(title: "Symmetry", value: averageSymmetry.map { "\(Int($0 * 100))%" } ?? "–",
                             symbol: "circle.lefthalf.filled", color: Theme.warm)
                }

                VStack(spacing: 14) {
                    ForEach(results) { result in
                        HStack(spacing: 12) {
                            Image(systemName: result.exercise.symbol)
                                .foregroundStyle(result.exercise.category.color)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.exercise.name).font(.headline)
                                Text("\(result.repsCompleted)/\(result.exercise.reps) reps · \(Int(result.intensity * 100))% of target")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let symmetry = result.symmetry {
                                Text("\(Int(symmetry * 100))%")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(Theme.color(forScore: symmetry * 100))
                            }
                        }
                    }
                }
                .card()

                Button("Done", action: onDone)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }
}
