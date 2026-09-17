import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Query private var history: [ExerciseSession]
    @State private var reps: Int
    @State private var hold: Double
    @State private var running = false

    init(exercise: Exercise) {
        self.exercise = exercise
        let id = exercise.id
        _history = Query(filter: #Predicate<ExerciseSession> { $0.exerciseID == id },
                         sort: \.date, order: .reverse)
        _reps = State(initialValue: exercise.reps)
        _hold = State(initialValue: exercise.holdSeconds)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "How to do it")
                    ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .frame(width: 24, height: 24)
                                .background(exercise.category.color.opacity(0.2), in: Circle())
                            Text(step)
                        }
                    }
                    if exercise.poses.count > 1 {
                        Text("One rep = " + exercise.poses.map(\.cue).joined(separator: " → "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Session")
                    Stepper("Reps: \(reps)", value: $reps, in: 1...30)
                    Stepper("Hold: \(hold.formatted())s", value: $hold, in: 1...15, step: 0.5)
                }
                .card()

                Button("Start") { running = true }
                    .buttonStyle(PrimaryButtonStyle(color: exercise.category.color))

                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "History")
                        ForEach(history.prefix(8)) { session in
                            HStack {
                                Text(session.date, format: .dateTime.day().month().hour().minute())
                                    .font(.subheadline)
                                Spacer()
                                Text("\(session.repsCompleted)/\(session.repsTarget) reps")
                                    .font(.subheadline.monospacedDigit())
                                if let symmetry = session.symmetry {
                                    Text("\(Int(symmetry * 100))% sym")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .card()
                }
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $running) {
            ExerciseSessionView(exercises: [exercise.with(reps: reps, holdSeconds: hold)])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: exercise.symbol)
                    .font(.system(size: 34))
                    .foregroundStyle(exercise.category.color)
                    .frame(width: 72, height: 72)
                    .background(exercise.category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name).font(.title2.bold())
                    Label(exercise.category.title, systemImage: exercise.category.symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(exercise.summary)
            Label(exercise.muscles, systemImage: "figure.strengthtraining.traditional")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
