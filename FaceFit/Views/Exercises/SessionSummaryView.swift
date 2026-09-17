import SwiftUI

struct SessionSummaryView: View {
    let results: [ExerciseResult]
    var onDone: () -> Void

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
